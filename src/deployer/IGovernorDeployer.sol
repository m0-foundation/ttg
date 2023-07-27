// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IGovernorDeployer {
    error CallerIsNotOwner();

    function deployGovernor(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        address spog,
        bytes32 salt
    ) external returns (address governor_);

    function getDeterministicGovernorAddress(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        address spog,
        bytes32 salt
    ) external view returns (address deterministicAddress_);

    function owner() external view returns (address owner);
}
