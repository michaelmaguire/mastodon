import { useEffect, useState } from "react";
import type { FC, ReactNode } from "react";

import TruanonVerified from "@/images/icons/truanon_verified.svg?react";
import { apiRequestGet } from "@/mastodon/api";
import { useAccount } from "@/mastodon/hooks/useAccount";

// TruAnon verified identity. Rendered the way the original fork did it: the
// member's native profile fields and the TruAnon verified rows share ONE
// connected `account__header__fields` box (see accounts.scss), as sibling `dl`
// rows — not a separate stack of cards. When TruAnon is active this box stands
// in for the native fields list (index.tsx), so the native metadata still shows
// as the first, un-verified rows.
//
// Row order:
//   * the member's native metadata fields (0–many; e.g. their rel=me link),
//   * "Verified Identity" — a link to their public TruAnon profile,
//   * "Personal" — gender/pronouns, age, then location, as one comma list,
//   * one row per social/contact property, linking via the full username path.
//
// Nothing identifying is stored: the TruAnon rows are fetched per view.

interface CardItem {
  type: string;
  name: string;
  display: string;
}

interface TruanonCardData {
  sections: {
    kind: string;
    label: string;
    items: CardItem[];
  }[];
  profile_url?: string | null;
  rank?: string;
  private_mode?: boolean;
}

interface Row {
  name: ReactNode;
  value: ReactNode;
  verified: boolean;
}

// Same test the original service used to decide link vs. plain text.
const isValidURL = (str: string) => /^[^\s.]+(\.[^\s]+)+$/.test(str);

const link = (display: string): ReactNode =>
  isValidURL(display) ? (
    <a href={`https://${display}`} target="_blank" rel="noopener noreferrer">
      {display}
    </a>
  ) : (
    display
  );

// Personal items show in a fixed order: identity, then age, then location.
const personalRank = (type: string): number => {
  if (/gender|pronoun/i.test(type)) return 0;
  if (/birthday|age|zodiac/i.test(type)) return 1;
  if (/location|city|address|street|state|country/i.test(type)) return 2;
  return 3;
};

export const TruanonFields: FC<{ accountId: string }> = ({ accountId }) => {
  const account = useAccount(accountId);
  const [data, setData] = useState<TruanonCardData | null>(null);

  useEffect(() => {
    let active = true;

    apiRequestGet<TruanonCardData>(`v1/accounts/${accountId}/truanon`)
      .then((result) => {
        if (active) {
          setData(result);
        }
        return result;
      })
      .catch(() => {
        // Not configured or unreachable — native fields still render.
      });

    return () => {
      active = false;
    };
  }, [accountId]);

  const rows: Row[] = [];

  // The member's native metadata fields (rendered first, verified per Mastodon).
  const nativeFields = account?.fields.toJS() as
    | {
        name_emojified: string;
        value_emojified: string;
        verified_at: string | null;
      }[]
    | undefined;

  nativeFields?.forEach((field) => {
    rows.push({
      name: <span dangerouslySetInnerHTML={{ __html: field.name_emojified }} />,
      value: (
        <span dangerouslySetInnerHTML={{ __html: field.value_emojified }} />
      ),
      verified: !!field.verified_at,
    });
  });

  if (data) {
    // Public profile link.
    if (data.profile_url) {
      rows.push({
        name: "Verified Identity",
        value: link(data.profile_url),
        verified: true,
      });
    }

    // Personal, collapsed into a single comma-separated row.
    const personal = data.sections.find(
      (section) => section.kind === "personal",
    );
    if (personal && personal.items.length > 0) {
      const values = [...personal.items]
        .sort((a, b) => personalRank(a.type) - personalRank(b.type))
        .map((item) => item.display);
      rows.push({ name: "Personal", value: values.join(", "), verified: true });
    }

    // Social + contact, one row each, labelled by the property's own name.
    // In private mode ("no links") the values show as plain text, not links.
    data.sections
      .filter((section) => section.kind !== "personal")
      .forEach((section) => {
        section.items.forEach((item) => {
          rows.push({
            name: item.name,
            value: data.private_mode ? item.display : link(item.display),
            verified: true,
          });
        });
      });
  }

  if (rows.length === 0) {
    return null;
  }

  const rankClass = data?.rank
    ? `truanon-rank-${data.rank.toLowerCase()}`
    : undefined;

  return (
    <div className="account__header__fields">
      {rows.map((row, index) => (
        <dl key={index} className={row.verified ? "verified" : undefined}>
          <dt className="translate">{row.name}</dt>
          <dd className="translate">
            {row.verified && (
              <TruanonVerified className={`truanon-mark ${rankClass ?? ""}`} />
            )}
            <span>{row.value}</span>
          </dd>
        </dl>
      ))}
    </div>
  );
};
