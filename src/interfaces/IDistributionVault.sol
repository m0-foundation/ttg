// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IDistributionVault {
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

    function distribute(address token) external;

    function claim(
        address token,
        uint256 startEpoch,
        uint256 endEpoch,
        address destination
    ) external returns (uint256 claimed);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function getClaimable(
        address token,
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256 claimable);
}
