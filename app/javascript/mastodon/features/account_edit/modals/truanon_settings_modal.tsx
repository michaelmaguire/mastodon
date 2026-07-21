import type { ChangeEventHandler, FC } from "react";
import { useCallback, useEffect, useState } from "react";

import { FormattedMessage, useIntl } from "react-intl";

import { fetchAccount } from "@/mastodon/actions/accounts";
import { apiRequestGet, apiRequestPut } from "@/mastodon/api";
import { Callout } from "@/mastodon/components/callout";
import { ToggleField } from "@/mastodon/components/form_fields";
import { LoadingIndicator } from "@/mastodon/components/loading_indicator";
import { me } from "@/mastodon/initial_state";
import { useAppDispatch } from "@/mastodon/store";

import type { DialogModalProps } from "../../ui/components/dialog_modal";
import { DialogModal } from "../../ui/components/dialog_modal";
import { messages } from "../index";

import classes from "./styles.module.scss";

interface TruanonSettings {
  wants_verified_identity: boolean;
  show_personal: boolean;
  show_contact: boolean;
  show_social: boolean;
  make_private: boolean;
}

// The editable counterpart to the "Identity display settings" section: the same
// switches that live on the Verification page, surfaced here as a modal (like
// Profile display settings). Reads and writes through /api/v1/truanon_settings.
export const TruanonSettingsModal: FC<DialogModalProps> = ({ onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const [settings, setSettings] = useState<TruanonSettings | null>(null);
  const [pending, setPending] = useState(false);

  useEffect(() => {
    let active = true;

    apiRequestGet<TruanonSettings>("v1/truanon_settings")
      .then((data) => {
        if (active) {
          setSettings(data);
        }
        return data;
      })
      .catch(() => {
        // Not configured or unreachable — the modal stays in its loading state.
      });

    return () => {
      active = false;
    };
  }, []);

  const handleToggle: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const { name, checked } = event.target;
      setSettings((prev) => (prev ? { ...prev, [name]: checked } : prev));
      setPending(true);

      apiRequestPut<TruanonSettings>("v1/truanon_settings", { [name]: checked })
        .then((data) => {
          setSettings(data);
          // The master switch changes the badge; re-fetch the account so it
          // updates in place (Unknown ⇄ rank) without a page reload.
          if (name === "wants_verified_identity" && me) {
            dispatch(fetchAccount(me));
          }
          return data;
        })
        .catch(() => {
          // Leave the optimistic value in place; the next open re-syncs.
        })
        .finally(() => {
          setPending(false);
        });
    },
    [dispatch],
  );

  if (!settings) {
    return <LoadingIndicator />;
  }

  // The display options only matter while the verified identity is shown.
  const displayDisabled = pending || !settings.wants_verified_identity;

  return (
    <DialogModal
      onClose={onClose}
      title={intl.formatMessage(messages.truanonTitle)}
      noCancelButton
    >
      <div className={classes.toggleInputWrapper}>
        <ToggleField
          checked={settings.wants_verified_identity}
          onChange={handleToggle}
          disabled={pending}
          name="wants_verified_identity"
          label={
            <FormattedMessage
              id="account_edit.truanon_settings.verified.title"
              defaultMessage="Use verified identity"
            />
          }
          hint={
            <FormattedMessage
              id="account_edit.truanon_settings.verified.hint"
              defaultMessage="When off, you appear as Unknown everywhere. Your anchor stays yours."
            />
          }
        />

        {/* The three display options, grouped without dividers between them. */}
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <ToggleField
            checked={settings.show_personal}
            onChange={handleToggle}
            disabled={displayDisabled}
            name="show_personal"
            label={
              <FormattedMessage
                id="account_edit.truanon_settings.personal.title"
                defaultMessage="Show personal details"
              />
            }
            hint={
              <FormattedMessage
                id="account_edit.truanon_settings.personal.hint"
                defaultMessage="Things like pronouns, age range, and general location."
              />
            }
          />

          <ToggleField
            checked={settings.show_contact}
            onChange={handleToggle}
            disabled={displayDisabled}
            name="show_contact"
            label={
              <FormattedMessage
                id="account_edit.truanon_settings.contact.title"
                defaultMessage="Show contact info"
              />
            }
            hint={
              <FormattedMessage
                id="account_edit.truanon_settings.contact.hint"
                defaultMessage="A verified email or phone, reduced for privacy."
              />
            }
          />

          <ToggleField
            checked={settings.show_social}
            onChange={handleToggle}
            disabled={displayDisabled}
            name="show_social"
            label={
              <FormattedMessage
                id="account_edit.truanon_settings.social.title"
                defaultMessage="Show social profiles"
              />
            }
            hint={
              <FormattedMessage
                id="account_edit.truanon_settings.social.hint"
                defaultMessage="The accounts and sites others already know you by."
              />
            }
          />
        </div>

        <ToggleField
          checked={settings.make_private}
          onChange={handleToggle}
          disabled={displayDisabled}
          name="make_private"
          label={
            <FormattedMessage
              id="account_edit.truanon_settings.private.title"
              defaultMessage="Private mode"
            />
          }
          hint={
            <FormattedMessage
              id="account_edit.truanon_settings.private.hint"
              defaultMessage="Your rank still shows, but nothing links out."
            />
          }
        />
      </div>

      <Callout
        title={
          <FormattedMessage
            id="account_edit.truanon_settings.hint.title"
            defaultMessage="Owners control privacy"
          />
        }
        icon={false}
      >
        <FormattedMessage
          id="account_edit.truanon_settings.hint.description"
          defaultMessage="You decide exactly how others view and share your identity on each instance across the Fediverse ."
        />
      </Callout>
    </DialogModal>
  );
};
