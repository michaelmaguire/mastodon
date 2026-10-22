# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FediverseVerifiedService do
  subject(:service) { described_class.new(account) }

  let(:issuer) { 'https://verify.example/actor' }
  let(:proof_url) { 'https://verify.example/n/abc123' }
  let(:account) { Fabricate(:account, username: 'alice') }
  let(:level) { 'legal_name' }
  let(:credential) do
    {
      '@context' => ['https://www.w3.org/ns/credentials/v2', { '@vocab' => 'https://w3id.org/fediverse-verified#' }],
      'type' => %w(VerifiableCredential FediverseVerifiedCredential),
      'issuer' => issuer,
      'credentialSubject' => {
        'id' => ActivityPub::TagManager.instance.uri_for(account),
        'account_profile_url' => ActivityPub::TagManager.instance.url_for(account),
        'verification_level' => level,
        'name' => 'Mario Rossi',
        'age_over_18' => true,
      },
      'proof' => { 'type' => 'DataIntegrityProof', 'cryptosuite' => 'eddsa-jcs-2022' },
    }
  end
  let(:issuer_actor) { Fabricate(:account, domain: 'verify.example', uri: issuer, actor_type: 'Service') }
  let(:signature_valid) { true }

  before do
    account.update!(fields: [{ 'name' => 'fediverse-verified name', 'value' => proof_url, 'verified_at' => Time.now.utc.iso8601 }])
    stub_request(:get, "#{proof_url}.json").to_return(status: 200, body: credential.to_json,
                                                       headers: { 'Content-Type' => 'application/vc+ld+json' })
    allow(ActivityPub::ObjectIntegrityProof).to receive(:new).and_return(
      instance_double(ActivityPub::ObjectIntegrityProof, verify_actor!: signature_valid ? issuer_actor : nil)
    )
    Setting.fediverse_verified_enabled = true
    Setting.fediverse_verified_trusted_issuers = issuer
  end

  describe '#refresh_cache!' do
    it 'caches level, 18+, name and issuer from a trusted, valid credential' do
      expect(service.refresh_cache!).to include(verified: true, rank: 'fediverse-verified name · 18+')
      expect(account.reload).to have_attributes(fediverse_verified_level: 'legal_name', fediverse_verified_age_over_18: true,
                                                fediverse_verified_name: 'Mario Rossi', fediverse_verified_issuer: issuer)
    end

    context 'when the signature is invalid' do
      let(:signature_valid) { false }

      it 'caches nothing' do
        expect(service.refresh_cache![:verified]).to be false
        expect(account.reload.fediverse_verified_level).to be_nil
      end
    end

    context 'when the issuer is not trusted here' do
      before { Setting.fediverse_verified_trusted_issuers = 'https://other.example/actor' }

      it 'caches nothing' do
        expect(service.refresh_cache![:verified]).to be false
      end
    end

    context 'when the credential names another account' do
      before { credential['credentialSubject']['id'] = 'https://elsewhere.example/users/bob' }

      it 'caches nothing' do
        expect(service.refresh_cache![:verified]).to be false
      end
    end

    context 'when it is a test proof (made with a test wallet)' do
      before { credential['evidence'] = [{ 'type' => 'FediverseVerifiedEvidence', 'identity_check_method' => 'mock' }] }

      it 'is rejected even from a trusted issuer' do
        expect(service.refresh_cache![:verified]).to be false
      end

      it 'is accepted only when test proofs are explicitly allowed' do
        ClimateControl.modify(FEDIVERSE_VERIFIED_ALLOW_TEST_PROOFS: 'true') do
          expect(service.refresh_cache![:verified]).to be true
        end
      end
    end

    context 'with the person level' do
      let(:level) { 'person' }

      it 'never caches a name' do
        service.refresh_cache!
        expect(account.reload).to have_attributes(fediverse_verified_level: 'person', fediverse_verified_name: nil)
      end
    end

    context 'when the link is not green-checked' do
      before { account.update!(fields: [{ 'name' => 'fediverse-verified name', 'value' => proof_url }]) }

      it 'does not look for a credential' do
        expect(service.refresh_cache![:verified]).to be false
        expect(a_request(:get, "#{proof_url}.json")).to_not have_been_made
      end
    end
  end

  describe '.cached_badge' do
    it 'describes the cached level for the REST API' do
      account.update_columns(fediverse_verified_level: 'person', fediverse_verified_age_over_18: false, fediverse_verified_issuer: issuer)
      expect(described_class.cached_badge(account)).to include(rank: 'fediverse-verified person', score: nil,
                                                               provider: 'fediverse_verified', issuer: issuer)
    end

    it 'gives no badge without a cached level' do
      expect(described_class.cached_badge(account)).to be_nil
    end
  end

  it 'covers remote accounts, unlike TruAnon' do
    expect(described_class.covers_remote_accounts?).to be true
    expect(TruAnonService.covers_remote_accounts?).to be false
  end
end
