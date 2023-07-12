// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IERC165 } from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IGovernor } from "../../lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";
import { IVotes } from "../../lib/openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
