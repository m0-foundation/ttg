// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault {
    using SafeERC20 for IERC20;

    address public immutable govSpogVoteAddress;
    address public immutable govSpogValueAddress;

    event Withdraw(address indexed account, address token, uint256 amount);

    constructor(address _govSpogVoteAddress, address _govSpogValueAddress) {
        govSpogVoteAddress = _govSpogVoteAddress;
        govSpogValueAddress = _govSpogValueAddress;
    }

    /// @dev Release vault's asset entire balance for the auction.
    /// @param token Address of token to withdraw
    /// @param account Address to withdraw to. Must support auction contract.
    function releaseAssetBalance(address token, address account) public {
        // TODO: add require that account must implement auction contract interface

        uint256 total = IERC20(token).balanceOf(address(this));
        require(msg.sender == ISPOGGovernor(govSpogValueAddress).spogAddress(), "Vault: withdraw not allowed");
        IERC20(token).safeTransfer(account, total);

        emit Withdraw(account, token, total);
    }

    /// @dev Withdraw a specific amount to msg.sender. Must be allowed to withdraw.
    /// @param token address Address of token to withdraw
    /// @param amount uint256 Amount of token to withdraw
    function withdraw(address token, uint256 amount) public {
        // TODO: create isAllowedToWithdraw function in govSpogVote
        // require(
        //     ISPOGGovernor(govSpogVoteAddress).isAllowedToWithdraw(msg.sender),
        //     "Vault: withdraw not allowed"
        // );

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
