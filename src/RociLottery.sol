// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.7;

import "./Interface/IMockRNG.sol";
import "./SortitionSumTreeFactory.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract RociLottery is Ownable {
    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    uint256 public wagers;
    uint256 public lottery;
    uint256 public version;

    uint256 public wagerPeriod;
    uint256 public totalWagers;

    uint256 public minimumFee = 1 ether;
    uint256 private constant MAX_TREE_LEAVES = 5;

    bytes32 public TREE_KEY;

    mapping(uint256 => mapping(address => uint256)) public record;

    mapping(address => uint256) public lotteryCurrency;

    IMockRNG rng;
    address public winner;

    SortitionSumTreeFactory.SortitionSumTrees internal sortitionSumTrees;

    function setRngContractAddress(address _addr) external onlyOwner {
        rng = IMockRNG(_addr);
    }

    function startLottery(uint256 _wagerPeriod) external onlyOwner {
        require(block.timestamp > wagerPeriod, "lottery active");
        require(totalWagers == 0, "draw not done yet");

        TREE_KEY = keccak256(abi.encodePacked("RociLottery", version));

        sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);
        wagerPeriod = block.timestamp + _wagerPeriod;

        version++;
    }

    function lotteryActive() public view returns (bool) {
        return wagerPeriod > block.timestamp;
    }

    function depositETH(address user) external payable {
        require(user.balance >= minimumFee, "amount not enough");
        lotteryCurrency[user] += msg.value;
    }

    function playLottery(uint256 _amount, address _user) external {
        require(lotteryActive() == true, "no lottery active");
        require(
            lotteryCurrency[_user] >= minimumFee && _amount >= minimumFee,
            "wager not enough"
        );

        uint256 userWager = record[lottery][_user];
        lotteryCurrency[_user] -= _amount;

        totalWagers += _amount;

        if (userWager > 0) {
            uint256 newBalance = userWager + _amount;
            sortitionSumTrees.set(
                TREE_KEY,
                newBalance,
                bytes32(uint256(uint160(_user)))
            );

            record[lottery][_user] = newBalance;
            return;
        }

        record[lottery][_user] = _amount;
        sortitionSumTrees.set(
            TREE_KEY,
            _amount,
            bytes32(uint256(uint160(_user)))
        );

        wagers++;
    }

    function draw() external {
        require(lotteryActive() == false, "lottery still active");
        require(wagers > 0, "no active wagers");
        rng.requestRandomNumber(wagers);

        uint256 randomNumber = rng.RNG(rng.uniqueID());
        if (randomNumber == 0) revert("try again");

        winner = address(
            uint160(uint256(sortitionSumTrees.draw(TREE_KEY, randomNumber)))
        );

        lotteryCurrency[winner] += totalWagers;
        totalWagers = 0;

        wagers = 0;
        lottery++;
    }

    function chanceOf(address _user) external view returns (uint256) {
        return
            sortitionSumTrees.stakeOf(
                TREE_KEY,
                bytes32(uint256(uint160(_user)))
            );
    }

    function withdrawETH(uint256 _amount) external {
        require(
            _amount <= lotteryCurrency[msg.sender],
            "not enough user ETH in contract"
        );
        require(address(this).balance >= _amount, "Contract balance low");

        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function getUserWagerForActiveLottery(address _user)
        external
        view
        returns (uint256)
    {
        return record[lottery][_user];
    }

    receive() external payable {}
}
