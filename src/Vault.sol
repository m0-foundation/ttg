// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault {
    using SafeERC20 for IERC20;

    event Withdraw(address indexed account, address token, uint256 amount);

    /**
     * Function to withdraw the vault's entire balance.
     *
     * @param token address Address of token to withdraw
     * @param account address Address to withdraw to
     */
    function withdraw(address token, address account) public {
        uint256 total = IERC20(token).balanceOf(address(this));
        // require(
        //     // require only SPOG to withdraw assets and send to an auction contract
        //     ,
        //     "Vault: withdraw not allowed"
        // );
        IERC20(token).safeTransfer(account, total);

        emit Withdraw(account, token, total);
    }

    /**
     * Function to withdraw the a specific amount to msg.sender.
     *
     * @param token address Address of token to withdraw
     * @param amount uint256 Amount of token to withdraw
     */
    function withdraw(address token, uint256 amount) public {
        // require(
        //     // require only addresses that are allowed to withdraw. Check must come from GovSPOG
        //     ,
        //     "Vault: withdraw not allowed"
        // );

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
