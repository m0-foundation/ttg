# TTG (Two Token Governance)

TTG (Two Token Governance) is an EVM-compatible, immutable governance module for managing the M^0 core protocol and future M^0 ecosystem periphery.

It is a governance mechanism that uses token voting to maintain lists and manage communal property. As its name implies, it primarily optimizes for token holder participation. A TTG is primarily used for **permissioning actors** and should not be used for funding/financing decisions.

## Development

### Installation

You may have to install the following tools to use this repository:

- [Foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [lcov](https://github.com/linux-test-project/lcov) to generate the code coverage report
- [yarn](https://classic.yarnpkg.com/lang/en/docs/install/) to manage npm dependencies
- [slither](https://github.com/crytic/slither) to static analyze contracts

Install dependencies:

```bash
npm i
forge install
```

### Compile

Run the following command to compile the contracts:

```bash
forge build
```

### Coverage

Forge is used for coverage, run it with:

```bash
yarn coverage
```

You can then consult the report by opening `coverage/index.html`:

```bash
open coverage/index.html
```

### Test

To run all tests:

```bash
forge test
```

Run test that matches a test contract:

```bash
forge test --mc <test-contract-name>
```

Test a specific test case:

```bash
forge test --mt <test-case-name>
```

To run slither:

```bash
yarn slither
```

### Code quality

[Prettier](https://prettier.io) is used to format Solidity code. Use it by running:

```bash
yarn prettier
```

[Solhint](https://protofire.github.io/solhint/) is used to lint Solidity files. Run it with:

```bash
yarn solhint
```

Or to autofix some issues:

```bash
yarn solhint-fix
```

## Deployment

Contracts are deployed via the use of pre-deterministic addresses. See [ContractHelper](https://github.com/MZero-Labs/common/blob/main/src/ContractHelper.sol#L6) in `common` repository.

It is important to properly set [`_DEPLOYER_NONCE`](https://github.com/MZero-Labs/ttg/blob/main/.env.example?plain=1#L5) in your `.env` config.

### Local

Start a local network with [Anvil](https://github.com/foundry-rs/foundry/tree/master/crates/anvil) by running:

```bash
anvil
```

Then run:

```bash
make deploy-local
```

### Sepolia

```bash
make deploy-sepolia
```

## TTG Smart Contract Architecture

<img width="1098" alt="ttg" src="https://github.com/MZero-Labs/ttg/assets/1220854/58866111-26f6-495d-8949-9cef00783f7c">
