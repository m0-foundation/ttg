// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISPOGVault {
    // Events
    event EpochAssetsDeposited(uint256 indexed epoch, address indexed token, uint256 amount);
    event EpochAssetsWithdrawn(uint256 indexed epoch, address indexed account, address indexed token, uint256 amount);

    // Errors
    error InvalidEpoch(uint256 invalidEpoch, uint256 currentEpoch);
    error EpochWithNoAssets();
    error AlreadyWithdrawn();

    function governor() external returns (address);

    function deposit(uint256 epoch, address token, uint256 amount) external;

    function withdraw(uint256[] memory epochs, address token) external returns (uint256);

    function deposits(uint256 epoch, address token) external view returns (uint256);

    function alreadyWithdrawn(uint256 epoch, address token, address account) external view returns (bool);
}
