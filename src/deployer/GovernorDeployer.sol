// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernorDeployer } from "./IGovernorDeployer.sol";

import { DualGovernor } from "../governor/DualGovernor.sol";

contract GovernorDeployer is IGovernorDeployer {
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert CallerIsNotOwner();

        _;
    }

    constructor(address owner_) {
        owner = owner_;
    }

    function deployGovernor(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        address comptroller,
        bytes32 salt
    ) public onlyOwner returns (address governor_) {
        governor_ = address(new DualGovernor{ salt: salt }(name, vote, value, voteQuorum, valueQuorum, comptroller));
    }

    /// @dev Returns the deterministic address of a proxy given some salt.
    function getDeterministicGovernorAddress(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        address comptroller,
        bytes32 salt
    ) public view returns (address deterministicAddress_) {
        // See https://docs.soliditylang.org/en/v0.8.7/control-structures.html#salted-contract-creations-create2
        deterministicAddress_ = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(DualGovernor).creationCode,
                                    abi.encode(name, vote, value, voteQuorum, valueQuorum, comptroller)
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}
