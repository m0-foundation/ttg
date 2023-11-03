// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

interface IDistributionVault {
    event Distribution(address indexed token, uint256 indexed epoch, uint256 amount);

    event Claim(address indexed token, address indexed account, uint256 indexed epoch, uint256 amount);

    error AlreadyClaimed();

    error EpochTooHigh();

    error TransferFailed();

    function distribute(address token) external;

    function claim(address token, uint256 epoch, address destination) external returns (uint256 claimed);

    function claim(address token, uint256[] calldata epochs, address destination) external returns (uint256 claimed);

    function claim(
        address token,
        uint256 startEpoch,
        uint256 endEpoch,
        address destination
    ) external returns (uint256 claimed);

    function claimableOfAt(address token, address account, uint256 epoch) external view returns (uint256 claimable);

    function claimableOfAt(
        address token,
        address account,
        uint256[] calldata epochs
    ) external view returns (uint256 claimable);

    function claimableOfBetween(
        address token,
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256 claimable);
}
