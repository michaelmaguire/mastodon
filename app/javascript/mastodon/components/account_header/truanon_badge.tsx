import { useCallback, useId, useState } from 'react';
import type { FC } from 'react';

import classNames from 'classnames';

import TruanonVerified from '@/images/icons/truanon_verified.svg?react';

import { Badge } from '../badge';
import { Popover } from '../popover';

import classes from './styles.module.scss';

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
              <strong>{rank}</strong> · {score} of 5
            </p>
            <p>
              A live measure of how much of this account&apos;s identity has been
              publicly connected and independently cross-checked. It updates on
              its own as that information changes.
            </p>
            <p>Verified through TruAnon.</p>
          </div>
        )}
      </Popover>
    </>
  );
};
