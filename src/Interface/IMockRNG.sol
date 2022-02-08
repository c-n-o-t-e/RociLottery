// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.7;

interface IMockRNG {
    function requestRandomNumber(uint256 _rng) external;

    function uniqueID() external view returns (bytes memory);

    function RNG(bytes memory _uniqueID) external view returns (uint256);
}
