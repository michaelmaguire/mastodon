import { useCallback, useId, useState } from 'react';
import type { FC } from 'react';

import classNames from 'classnames';

import TruanonVerified from '@/images/icons/truanon_verified.svg?react';

import { Badge } from '../badge';
import { Popover } from '../popover';

import classes from './styles.module.scss';

// What each rank means, in Mastodon terms — the links and profiles others
// already know you by, without giving up a pseudonym or private details.
const RANK_COPY: Record<string, string> = {
  Genuine:
    'Genuine is the deepest rank — a consistent, transparent presence anchored to accounts and sites across several platforms that others already know and can check for themselves.',
  Reliable:
    'Reliable reflects a strong, consistent presence — anchored to several accounts and sites others can recognize and check.',
  Credible:
    'Credible reflects an established presence — anchored to accounts or sites others can recognize.',
  Cautioned:
    'Cautioned reflects a thin or inconsistent presence, with fewer anchored links for others to cross-check.',
  Dangerous:
    'Dangerous reflects signals that do not hold up to cross-checking — worth extra care.',
};

// The inline verified-identity badge. Like Mastodon's "owner" badge it doesn't
// link anywhere, but — modeled on the native handle "?" popover — clicking it
// opens a short, self-explanatory note about what the rank means.
export const TruanonBadge: FC<{ rank: string; score: string }> = ({
  rank,
  score,
}) => {
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
        type='button'
        ref={setTriggerElement}
        onClick={toggle}
        aria-expanded={open}
        aria-controls={accessibilityId}
        style={{
          display: 'inline-flex',
          padding: 0,
          border: 'none',
          background: 'none',
          font: 'inherit',
          color: 'inherit',
          cursor: 'pointer',
        }}
      >
        <Badge
          icon={<TruanonVerified />}
          label={`${rank} (${score} of 5)`}
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
            role='region'
            id={accessibilityId}
            className={classNames('dropdown-animation', classes.handleHelp)}
          >
            <h3>Verified identity</h3>
            <p>
              <strong
                style={{
                  color: `var(--truanon-${rank.toLowerCase()}, currentColor)`,
                }}
              >
                {rank}
              </strong>{' '}
              · {score} of 5
            </p>
            <p>
              {RANK_COPY[rank] ??
                'A live measure of how much of this identity is anchored to a public presence others can check.'}
            </p>
            <p>
              The rank stays current on its own. The account holder chooses what
              appears here — a pseudonym and private details stay private; only
              the links they want to be known by are shown.
            </p>
          </div>
        )}
      </Popover>
    </>
  );
};
