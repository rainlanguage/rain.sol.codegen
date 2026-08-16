# audit

## `mutation-test-scans.json`

The adversarial mutation-test scan ledger: a JSON array of records, one per
campaign run, **appended in run order**. The last element is the most recent
scan. Every element is a historical fact about the tree its `commit` names and
is never edited.

`commit` is the exact SHA a campaign probed; `publishedTag` and
`commitsAheadOfTag` locate that SHA against releases. The ledger states which
trees have been scanned and nothing beyond that — whether the newest scan still
describes the working tree is a fact about `HEAD`, which no record can carry. A
reader who needs it measures the distance themselves:

```
git rev-list --count "$(jq -r '.[-1].commit' audit/mutation-test-scans.json)"..HEAD
```

Nothing in this repo enforces the ordering rule above. A record appended out of
run order, or one carrying a malformed or missing `timestamp`, is caught by no
test here, so `.[-1]` is the newest scan by convention rather than by proof.

The record schema belongs to
[`rainlanguage/adversarial-mutation-test`](https://github.com/rainlanguage/adversarial-mutation-test).
Its README carries the field template, and its `SKILL.md` is where the rule that
a campaign closes by appending here lives.

## `protofire/`

The Protofire audit report, its filename carrying the commit the report covers.
