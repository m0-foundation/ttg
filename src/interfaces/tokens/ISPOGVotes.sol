// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISPOGVotes is IVotes, IERC20 {
    function initSPOGAddress(address _spogAddress) external;

    function mint(address account, uint256 amount) external;

    function MINTER_ROLE() external view returns (bytes32);
}
