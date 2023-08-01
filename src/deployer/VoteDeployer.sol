// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IVoteDeployer } from "./IVoteDeployer.sol";

import { VOTE } from "../tokens/VOTE.sol";

contract VoteDeployer is IVoteDeployer {
    address public owner;
    address public governor;

    modifier onlyOwner() {
        if (msg.sender != owner) revert CallerIsNotOwner();

        _;
    }

    constructor(address owner_) {
        owner = owner_;
    }

    function deployVote(
        string memory name,
        string memory symbol,
        address registrar,
        address value,
        address expectedGovernor,
        bytes32 salt
    ) public onlyOwner returns (address vote) {
        // Set public governor so that VOTE deployment cn access it during it's constructor.
        // NOTE: Registrar does not exist during its own constructor, so VOTE cannot read the expected governor from it.
        governor = expectedGovernor;

        vote = address(new VOTE{ salt: salt }(name, symbol, registrar, value));

        // Only needed this during the deployment of VOTE. Can be deleted so save gas.
        delete governor;
    }

    /// @dev Returns the deterministic address of a proxy given some salt.
    function getDeterministicVoteAddress(
        string memory name,
        string memory symbol,
        address registrar,
        address value,
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
                                abi.encodePacked(type(VOTE).creationCode, abi.encode(name, symbol, registrar, value))
                            )
                        )
                    )
                )
            )
        );
    }
}
