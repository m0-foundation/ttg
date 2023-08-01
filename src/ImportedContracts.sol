// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { Checkpoints } from "../lib/openzeppelin-contracts/contracts/utils/Checkpoints.sol";
import { ECDSA } from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { ERC20Snapshot } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import { ERC20Votes } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Governor } from "../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import { Initializable } from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { Math } from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SafeCast } from "../lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
