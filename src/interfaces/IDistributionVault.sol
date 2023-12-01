// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC712 } from "../../lib/common/src/interfaces/IERC712.sol";

interface IDistributionVault is IERC712 {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error AlreadyClaimed();

    error EpochTooHigh();

    error TransferFailed();

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event Claim(address indexed token, address indexed account, uint256 startEpoch, uint256 endEpoch, uint256 amount);

    event Distribution(address indexed token, uint256 indexed epoch, uint256 amount);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function claim(
        address token,
        uint256 startEpoch,
        uint256 endEpoch,
        address destination
    ) external returns (uint256 claimed);

    function claimBySig(
        address account,
        address token,
        uint256 startEpoch,
        uint256 endEpoch,
        address destination,
        uint256 deadline,
        bytes memory signature
    ) external returns (uint256 claimed);

    function distribute(address token) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function CLAIM_TYPEHASH() external view returns (bytes32 typehash);

    function getClaimable(
        address token,
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256 claimable);

    function name() external view returns (string memory name);
}
