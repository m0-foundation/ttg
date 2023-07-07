// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/interfaces/ISPOGControlled.sol";

interface ISPOGVotes is ISPOGControlled, IERC20 {
    function MINTER_ROLE() external view returns (bytes32);

    function mint(address to, uint256 amount) external;
}
