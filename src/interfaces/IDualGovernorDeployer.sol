// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IDualGovernorDeployer {
    error CallerIsNotRegistrar();

    error ZeroCashTokenAddress();

    error ZeroRegistrarAddress();

    error ZeroVaultAddress();

    error ZeroZeroTokenAddress();

    function deploy(
        address powerToken,
        uint256 proposalFee,
        uint256 maxTotalZeroRewardPerActiveEpoch,
        uint16 powerTokenThresholdRatio,
        uint16 zeroTokenThresholdRatio
    ) external returns (address deployed);

    function allowedCashTokens() external view returns (address[] memory tokens);

    function allowedCashTokensAt(uint256 index) external view returns (address token);

    function getNextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function vault() external view returns (address vault);

    function zeroToken() external view returns (address zeroToken);
}
