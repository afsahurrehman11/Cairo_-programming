# Voting Contract — Guide

## Overview

`voting_cont.cairo` implements a simple single-question voting contract with:
- an owner (who can close the vote),
- a question (stored as `felt252`),
- two counters for `yes` and `no` votes (stored as `u128`),
- an `is_open` flag to indicate whether voting is allowed,
- a `has_voted` mapping from addresses to `bool` to prevent double-voting.

The contract emits events when votes are cast and when voting is closed.

## Storage layout

Declared in the `#[storage] struct Storage`:
- `owner: ContractAddress` — address that deployed/initialized the contract and can close voting.
- `question: felt252` — the question text or identifier; stored as a `felt252`.
- `yes_votes: u128` — number of affirmative votes.
- `no_votes: u128` — number of negative votes.
- `is_open: bool` — whether voting is currently open.
- `has_voted: Map<ContractAddress, bool>` — per-address flag indicating whether the address has already voted.

Notes:
- `u128` counters are used to allow a very large number of votes while keeping arithmetic straightforward.
- `Map<ContractAddress, bool>` is the canonical StarkNet storage map used to record per-address state.

## Events

Two events are defined:
- `VoteCast` — emitted when a voter casts their vote. Contains `voter: ContractAddress` and `support: bool`.
- `VotingClosed` — emitted when the owner closes the voting session. Contains `closed_by: ContractAddress`.

Events are useful for off-chain indexing and proving that actions occurred.

## Constructor

Signature: `constructor(ref self: ContractState, question: felt252)`

Behavior:
- Sets `owner` to `get_caller_address()` (the deployer)
- Writes `question` into storage
- Sets `is_open` to `true`

This makes the deployer the owner with the exclusive right to close the voting.

## External functions (public API)

All externally callable functions are marked `#[external(v0)]`.

- `vote(ref self: ContractState, support: bool)`
  - Purpose: cast a vote.
  - Preconditions:
    - `is_open` must be `true` (otherwise assertion `'Voting is closed'` fails).
    - The caller's address must not already be in `has_voted` (otherwise assertion `'Already voted'` fails).
  - Effects:
    - Writes `true` to `has_voted[caller]` to prevent double-voting.
    - Increments `yes_votes` if `support` is `true`; otherwise increments `no_votes`.
    - Emits `VoteCast` with the `voter` and `support` flag.

- `close_voting(ref self: ContractState)`
  - Purpose: close the voting session (owner-only).
  - Preconditions:
    - `caller == owner` or assertion `'Only owner can close voting'` fails.
    - `is_open` must be `true` or assertion `'Voting already closed'` fails.
  - Effects:
    - Sets `is_open` to `false`.
    - Emits `VotingClosed` with `closed_by` set to the caller.

- `get_question(self: @ContractState) -> felt252`
  - Read-only accessor returning the stored `question`.

- `get_owner(self: @ContractState) -> ContractAddress`
  - Read-only accessor returning the `owner` address.

- `is_voting_open(self: @ContractState) -> bool`
  - Read-only accessor returning the `is_open` flag.

- `get_results(self: @ContractState) -> (u128, u128)`
  - Read-only accessor returning `(yes_votes, no_votes)`.

- `has_address_voted(self: @ContractState, voter: ContractAddress) -> bool`
  - Read-only accessor returning whether the provided `voter` address already voted.

## Data types and calldata conventions

- `support: bool` — represented as a boolean; when interacting at low-level, this is passed as a single value (`1` for `true`, `0` for `false`).
- `ContractAddress` — the typed address used throughout the contract for the owner and voter keys.
- `felt252` — used for the `question`; it can encode numeric identifiers or short textual values encoded as felts.
- `u128` — chosen for vote counters to avoid overflow for reasonable vote sizes.

## Assertions and error messages

The contract uses `assert(condition, 'message')` for checks. Messages present in the source are:
- `'Voting is closed'` — when `vote` is called while `is_open` is false.
- `'Already voted'` — when a caller tries to vote twice.
- `'Only owner can close voting'` — when a non-owner attempts to close the vote.
- `'Voting already closed'` — when `close_voting` is called but `is_open` is already false.

## State transitions and invariants

- Initial state after constructor: `is_open == true`, `yes_votes == 0`, `no_votes == 0`, `has_voted` empty.
- Each successful `vote` sets `has_voted[caller] = true` and increments exactly one of the counters.
- After `close_voting`, `is_open == false`, blocking further `vote` calls.
- Invariant: `yes_votes + no_votes == number_of_true_entries_in_has_voted` (assuming no other writes to those fields). This holds if callers only interact via `vote` and `has_voted` is only set inside `vote`.

## Events and off-chain indexing

Listeners should track `VoteCast` to reconstruct who voted and their choice, and `VotingClosed` to know when the voting was finalized.

## Deploying the Contract locally

Follow this [guide](https://docs.starknet.io/build/quickstart/environment-setup) to download dependencies.

In a terminal session run this command, and keep it running.
```
starknet-devnet --seed=0
```

In a different terminal session navigate to project root and run:
```
sncast account import \
    --address=<account_address> \
    --type=oz \
    --url=http://127.0.0.1:5050 \
    --private-key=<account_priv_key> \
    --add-profile=devnet \
    --silent
```
This will create a file ```snfoundry.toml```. Say if you want to add another profile for voting change ```addresss```, ```private-key``` and ```add-profile``` fields.

Declare the contract:
```
sncast --profile=devnet declare \
    --contract-name=VotingContract
```

Deploy the contract:
```
sncast --profile=devnet deploy \
    --class-hash=<class_hash_generated_by_prev_command> \
    --constructor-calldata="q" --salt=0
```

Then invoke or call the public API like the following examples:

```
sncast --profile=devnet invoke \
    --contract-address=<contract_addr_generated_by_deploy_command> \
    --function=vote \
    --arguments=true
```

```
sncast --profile=devnet call \
    --contract-address=<contract_addr_generated_by_deploy_command> \
    --function=get_results
```