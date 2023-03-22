// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface ISPOGVotes is IVotes {
    function initSPOGAddress(address _spogAddress) external;

    function mint(address account, uint256 amount) external;

    function MINTER_ROLE() external view returns (bytes32);
}
