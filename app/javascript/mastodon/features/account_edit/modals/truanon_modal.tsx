import type { FC } from "react";

import { FormattedMessage } from "react-intl";

import type { DialogModalProps } from "../../ui/components/dialog_modal";
import { DialogModal } from "../../ui/components/dialog_modal";

import classes from "./styles.module.scss";

// The identity-verification companion to the "How to add a verified link"
// modal: explains anchoring a verified identity and controlling what others
// see, then points to the Verification page where the anchor flow and privacy
// switches live.
export const TruanonModal: FC<DialogModalProps> = ({ onClose }) => (
  <DialogModal
    onClose={onClose}
    title={
      <FormattedMessage
        id="account_edit.truanon_modal.title"
        defaultMessage="How do I securely anchor my identity?"
      />
    }
    noCancelButton
    wrapperClassName={classes.wrapper}
  >
    <FormattedMessage
      id="account_edit.truanon_modal.details"
      defaultMessage="Anchoring your identity makes blogs and social platforms easy to verify even when they don't support rel=me or HTML editing. Now you choose how you're known: reveal verified properties or simply the rank of confidence they represent."
      tagName="p"
    />

    <ol className={classes.verifiedSteps}>
      <li>
        <FormattedMessage
          id="account_edit.truanon_modal.step1.header"
          defaultMessage="Anchor your identity"
          tagName="h2"
        />
        <FormattedMessage
          id="account_edit.truanon_modal.step1.details"
          defaultMessage="On the Verification page, anchor your identity to your profile only once. Your trusted rank and badge build trust across this server."
          tagName="p"
        />
      </li>
      <li>
        <FormattedMessage
          id="account_edit.truanon_modal.step2.header"
          defaultMessage="Choose what others see"
          tagName="h2"
        />
        <FormattedMessage
          id="account_edit.truanon_modal.step2.details"
          defaultMessage="Grant or revoke visibility as you wish — stay fully private - you decide how others view and share your identity but the trust and confidence of your verified properties is always with you."
          tagName="p"
        />
      </li>
    </ol>

    <a href="/settings/verification" className="button">
      <FormattedMessage
        id="account_edit.truanon_modal.manage"
        defaultMessage="Go to Verification"
      />
    </a>
  </DialogModal>
);
