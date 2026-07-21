import { useCallback, useId, useState } from "react";
import type { FC } from "react";

import classNames from "classnames";

import TruanonVerified from "@/images/icons/truanon_verified.svg?react";

import { Badge } from "../badge";
import { Popover } from "../popover";

import classes from "./styles.module.scss";

// What each rank means, in Mastodon terms — the links and profiles others
// already know you by, without giving up a pseudonym or private details.
const RANK_COPY: Record<string, string> = {
  Genuine:
    "Genuine is the strongest confidence — a consistent, lenghty presence anchored to accounts and sites across platforms.",
  Reliable:
    "Reliable reflects a strong, consistent presence — anchored to several accounts and sites others can recognize and check.",
  Credible:
    "Credible is as good as ID — anchored to accounts or sites others can recognize and history they can explore.",
  Cautioned:
    "Cautioned reflects a thin or transitional state, with fewer anchored links for others to cross-check.",
  Dangerous:
    "Dangerous reflects signals that do not hold up to cross-checking — ignore these members.",
  Unknown:
    "Unknown status means no identity is being shown — this account hasn’t anchored one yet, or has turned it off.",
};

// The inline verified-identity badge. Like Mastodon's "owner" badge it doesn't
// link anywhere, but — modeled on the native handle "?" popover — clicking it
// opens a short, self-explanatory note about what the rank means.
export const TruanonBadge: FC<{ rank: string; score: string | null }> = ({
  rank,
  score,
}) => {
  const isUnknown = rank === "Unknown";
  const accessibilityId = useId();
  const [open, setOpen] = useState(false);
  const [triggerElement, setTriggerElement] =
    useState<HTMLButtonElement | null>(null);

  const toggle = useCallback(() => {
    setOpen((prev) => !prev);
  }, []);

  return (
    <>
      <button
        type="button"
        ref={setTriggerElement}
        onClick={toggle}
        aria-expanded={open}
        aria-controls={accessibilityId}
        style={{
          display: "inline-flex",
          padding: 0,
          border: "none",
          background: "none",
          font: "inherit",
          color: "inherit",
          cursor: "pointer",
        }}
      >
        <Badge
          icon={<TruanonVerified />}
          label={isUnknown ? rank : `${rank} (${score} of 5)`}
          className={classNames(classes.truanonBadge, classes[`rank${rank}`])}
        />
      </button>

      <Popover
        isOpen={open}
        reference={triggerElement}
        onClose={toggle}
        offset={5}
      >
        {({ props }) => (
          <div
            {...props}
            role="region"
            id={accessibilityId}
            className={classNames("dropdown-animation", classes.handleHelp)}
          >
            <h3>Verified identity</h3>
            <p>
              <strong
                style={{
                  color: `var(--truanon-${rank.toLowerCase()}, currentColor)`,
                }}
              >
                {rank}
              </strong>
              {!isUnknown && <> · {score} of 5</>}
            </p>
            <p>
              {RANK_COPY[rank] ??
                "A live measure of how much of this identity is anchored to a public presence others can check."}
            </p>
            <p>
              The badge is continuous and automatic, the account owner decides
              how others view and share identity details.
            </p>
          </div>
        )}
      </Popover>
    </>
  );
};
