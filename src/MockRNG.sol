// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.7;

contract MockRNG {
    bytes public uniqueID;
    mapping(bytes => uint256) public RNG;

    function requestRandomNumber(uint256 _rng) external {
        bytes memory _uniqueID = abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender
        );
        uint256 rng = fulfill(_rng + 1, _uniqueID);

        RNG[_uniqueID] = rng;
        uniqueID = _uniqueID;
    }

    function fulfill(uint256 _rng, bytes memory _uniqueID)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(_uniqueID)) % _rng;
    }
}
