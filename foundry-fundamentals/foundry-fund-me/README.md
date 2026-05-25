# Foundry FundMe

A minimal Ethereum smart contract project built with Foundry.

This repository implements a simple `FundMe` contract that allows users to fund the contract with ETH and enables the contract owner to withdraw the funds.

## Project Structure

- `src/FundMe.sol` - Main `FundMe` contract.
- `src/PriceConverter.sol` - Library that reads the Chainlink price feed and converts ETH to USD.
- `script/DeployFundMe.s.sol` - Deployment script used by Forge.
- `script/HelperConfig.s.sol` - Provides network-specific price feed configuration for Sepolia and local Anvil.
- `test/unit/FundMeTest.t.sol` - Unit tests for `FundMe` logic.
- `test/mocks/MockV3Aggregator.sol` - Local mock price feed contract.

## Features

- Accepts ETH deposits via `fund()`.
- Requires a minimum funding amount of `5 USD` worth of ETH.
- Records funders and funded amounts.
- Allows only the contract owner to withdraw funds.
- Supports `withdraw()` and `cheaperWithdraw()` functions.
- Accepts ETH through `receive()` and `fallback()`.

## Prerequisites

- `foundryup` installed and configured.
- `forge`, `cast`, and `anvil` available on your PATH.
- `git` and `curl` as needed for Foundry installation.

## Setup

```bash
forge install
forge build
```

## Testing

Run the full test suite with:

```bash
forge test
```

Test coverage includes:

- Minimum USD requirement enforcement.
- Funding flow and data structure updates.
- Owner-only withdrawal restrictions.
- Withdrawal behavior with a single funder and multiple funders.
- `cheaperWithdraw()` behavior.

## Deployment

### Local deployment using Anvil

Start Anvil in a separate terminal:

```bash
anvil
```

Then deploy the contract locally:

```bash
forge script script/DeployFundMe.s.sol:DeployFundMe --broadcast --rpc-url http://127.0.0.1:8545
```

### Sepolia deployment

This project uses a Chainlink ETH/USD price feed when on Sepolia.

Deploy with:

```bash
forge script script/DeployFundMe.s.sol:DeployFundMe --broadcast --rpc-url <SEPOLIA_RPC_URL> --private-key <PRIVATE_KEY>
```

**Deployed contract address:** `0x6F70181Cd37a924C087AE2305ad439b20cB93e3c`

## Price Feed Configuration

- On Sepolia (`chainid == 11155111`), `HelperConfig` uses the official Sepolia ETH/USD price feed address.
- On local Anvil, `HelperConfig` deploys a `MockV3Aggregator` with a fixed price.

## Notes

- The `FundMe` contract uses `PriceConverter` to calculate the USD value of ETH contributions.
- The contract owner is set in the constructor and stored as an immutable owner variable.
- The `onlyOwner` modifier reverts with a custom error `FundMe_NotOwner()` when called by non-owners.

## Useful Commands

```bash
forge build
forge test
forge fmt
forge script script/DeployFundMe.s.sol:DeployFundMe --broadcast --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```
