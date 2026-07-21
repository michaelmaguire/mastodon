import { useState, useCallback } from 'react';

import classNames from 'classnames';
import { Link } from 'react-router-dom';

import { useHovering } from 'mastodon/hooks/useHovering';
import { autoPlayGif } from 'mastodon/initial_state';
import type { Account, AccountShapeFull } from 'mastodon/models/account';

import { useAccount } from '../hooks/useAccount';

interface Props {
  account?: Pick<
    Account | AccountShapeFull,
    'id' | 'acct' | 'avatar' | 'avatar_static' | 'verified_identity'
  >;
  alt?: string;
  size?: number | null;
  style?: React.CSSProperties;
  inline?: boolean;
  animate?: boolean;
  withLink?: boolean;
  counter?: number | string;
  counterBorderColor?: string;
  className?: string;
}

export const Avatar: React.FC<Props> = ({
  account,
  alt = '',
  animate = autoPlayGif,
  size = 20,
  inline = false,
  withLink = false,
  style: styleFromParent,
  className,
  counter,
  counterBorderColor,
}) => {
  const { hovering, handleMouseEnter, handleMouseLeave } = useHovering(animate);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  // Subtle rank ring: the member's cached TruAnon rank tints the avatar edge
  // wherever it appears, no per-post fetch. Only present when the member is
  // showing their verified identity (the serializer gates on that).
  // Ring only for an actual rank — "Unknown" (unanchored / turned off) shows
  // its badge on the profile but no avatar ring, to keep the ring meaningful.
  const rank = account?.verified_identity?.rank;
  const hasRankRing = !!rank && rank !== 'Unknown';
  // border-box keeps the border inside the avatar's fixed size — no layout
  // shift — and cleanly recolors the 1px border some avatars already have.
  const rankStyle = hasRankRing
    ? {
        border: `1px solid var(--identity-rank-${rank.toLowerCase()}, transparent)`,
        boxSizing: 'border-box' as const,
      }
    : {};
  const style =
    size !== null
      ? {
          ...styleFromParent,
          width: `${size}px`,
          height: `${size}px`,
          ...rankStyle,
        }
      : { ...styleFromParent, ...rankStyle };

  const src = hovering || animate ? account?.avatar : account?.avatar_static;

  const handleLoad = useCallback(() => {
    setLoading(false);
  }, [setLoading]);

  const handleError = useCallback(() => {
    setError(true);
  }, [setError]);

  const avatar = (
    <span
      className={classNames(className, 'account__avatar', {
        'account__avatar--inline': inline,
        'account__avatar--loading': loading,
      })}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      style={style}
    >
      {src && !error && (
        <img src={src} alt={alt} onLoad={handleLoad} onError={handleError} />
      )}

      {counter && (
        <span
          className='account__avatar__counter'
          style={{ borderColor: counterBorderColor }}
        >
          {counter}
        </span>
      )}
    </span>
  );

  if (withLink) {
    return (
      <Link
        to={`/@${account?.acct}`}
        title={`@${account?.acct}`}
        data-hover-card-account={account?.id}
      >
        {avatar}
      </Link>
    );
  }

  return avatar;
};

export const AvatarById: React.FC<
  { accountId: string | undefined } & Omit<Props, 'account'>
> = ({ accountId, ...otherProps }) => {
  const account = useAccount(accountId);
  return <Avatar account={account} {...otherProps} />;
};
