// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import "src/interfaces/tokens/ISPOGVotes.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IValue is IVotes, ISPOGVotes {
    function snapshot() external returns (uint256);
}
