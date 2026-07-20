import type { FC } from "react";

import { FormattedMessage } from "react-intl";

import type { DialogModalProps } from "../../ui/components/dialog_modal";
import { DialogModal } from "../../ui/components/dialog_modal";

import classes from "./styles.module.scss";

// The TruAnon companion to the "How to add a verified link" modal: explains
// anchoring a verified identity and controlling what others see, then points to
// the Verification page where the anchor flow and privacy switches live.
export const TruanonModal: FC<DialogModalProps> = ({ onClose }) => (
  <DialogModal
    onClose={onClose}
    title={
      <FormattedMessage
        id="account_edit.truanon_modal.title"
        defaultMessage="How do I securely anchor my profile?"
      />
    }
    noCancelButton
    wrapperClassName={classes.wrapper}
  >
    <FormattedMessage
      id="account_edit.truanon_modal.details"
      defaultMessage="Anchoring confirms who you are one-time only, then reflects a rank across the Fediverse — amplifying your profile while you stay in control of what others see. Unlike a single verified link, it stays current on its own."
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
          defaultMessage="On the Verification page, anchor your identity to the accounts and sites others already know you by. Your rank and badge then follow you across this server."
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
          defaultMessage="Grant or revoke visibility of your personal, contact, and social details — or stay fully private and show only your rank. A pseudonym and private information stay private."
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
