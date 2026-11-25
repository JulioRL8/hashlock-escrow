# Hashlock Escrow

A single-use ETH escrow with a hash preimage for claims and a timeout for refunds.

## How it works

1. The sender generates a secret off-chain and deploys with its Keccak-256 digest, a beneficiary, a duration, and the escrowed ETH.
2. Before expiry, anyone can submit the secret via `claim(secret)`. ETH always goes to the beneficiary.
3. From `expiresAt` onward, anyone can call `refund()` to return the ETH to the original sender.

Use a random 32-byte secret. A successful claim reveals it publicly. A rejecting recipient can leave that path unavailable.

## Build and test

Install [Foundry](https://getfoundry.sh/) and run these commands from this directory. Forge selects Solidity 0.8.36 from `foundry.toml`. The project has no third-party Solidity dependencies.

```bash
forge build
forge test -vv
forge coverage --exclude-tests
```

## Local deployment

Start a fresh `anvil` node in a separate terminal. Deploy with the first unlocked account on that local node.

```bash
export RPC_URL=http://127.0.0.1:8545
export ANVIL_ACCOUNT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
DEMO_SECRET=0x0000000000000000000000000000000000000000000000000000000000000001
forge create src/HashlockEscrow.sol:HashlockEscrow --rpc-url "$RPC_URL" --from "$ANVIL_ACCOUNT" --unlocked --broadcast --value 1ether --constructor-args "$ANVIL_ACCOUNT" "$(cast keccak "$DEMO_SECRET")" 3600
```

## Local example

Set `CONTRACT` to the address printed by `forge create` and keep using the same terminal. The example uses a public demo preimage suitable for the local node.

```bash
export ETH_RPC_URL="$RPC_URL"
CONTRACT=0x... # Replace with your deployed address.
cast send "$CONTRACT" 'claim(bytes32)' "$DEMO_SECRET" --from "$ANVIL_ACCOUNT" --unlocked
cast call "$CONTRACT" 'settled()(bool)'
```

## Test cases

Foundry reports 8 passing tests and 100% coverage on contract lines, statements, branches and functions.

- Valid and invalid preimages, caller-independent payouts and timeout refunds.
- Mutually exclusive settlement and rollback on a rejected ETH transfer.
- Fuzzed secrets and deposit amounts.
