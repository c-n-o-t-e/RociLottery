// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "ds-test/test.sol";
import "../RociLottery.sol";

interface Hevm {
    function prank(address h) external;

    function expectRevert(bytes calldata expectedError) external;

    function addr(uint256) external returns (address);

    function warp(uint256 x) external;

    function roll(uint256 x) external;
}

interface test {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract RociLotteryTest is DSTest {
    RociLottery rociLottery;

    Hevm hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        rociLottery = new RociLottery(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9,
            0xa36085F69e2889c224210F603D836748e7dC0088
        );

        //sending 0.1 LINK to contract
        test(0xa36085F69e2889c224210F603D836748e7dC0088).transfer(
            address(rociLottery),
            100000000000000000
        );
    }

    function sendETH(uint256 amount, address _addr) public {
        payable(_addr).transfer(amount);
    }

    function testNotOwner() public {
        hevm.prank(0x9f9433aa66A6E130D45bAc7c6754d859C030c897);
        hevm.expectRevert("Ownable: caller is not the owner");
        rociLottery.startLottery(100);
    }

    function testNotToDepositETH() external {
        hevm.expectRevert("amount not enough");
        rociLottery.depositETH{value: 1 ether}(hevm.addr(1));
    }

    function testStartLottery() external {
        hevm.warp(1000);
        rociLottery.startLottery(100);

        assertEq(
            rociLottery.TREE_KEY(),
            keccak256(
                abi.encodePacked("RociLottery", rociLottery.version() - 1)
            )
        );
    }

    function testShouldFailToDepositETH() external {
        hevm.expectRevert("amount not enough");
        rociLottery.depositETH{value: 1 ether}(hevm.addr(1));
    }

    function testDepositETH() external {
        sendETH(1 ether, hevm.addr(1));

        rociLottery.depositETH{value: 1 ether}(hevm.addr(1));
        assertEq(1 ether, rociLottery.lotteryCurrency(hevm.addr(1)));
    }

    function testShouldFailIfLotteryIsNotActive() external {
        hevm.expectRevert("no lottery active");
        rociLottery.playLottery(1 ether, hevm.addr(1));
    }

    function testShouldFailIfAmountIsLessThanMinimiumFee() external {
        hevm.warp(1000);
        rociLottery.startLottery(100);
        hevm.expectRevert("wager not enough");
        rociLottery.playLottery(1 gwei, hevm.addr(1));
    }

    function testPlayLottery() external {
        sendETH(2 ether, hevm.addr(1));
        uint256 amount = 1 ether;

        rociLottery.depositETH{value: amount}(hevm.addr(1));
        uint256 totalWagersBeforeTx = rociLottery.totalWagers();

        uint256 userSortitionSumTreeStakeBeforeTx = rociLottery.chanceOf(
            hevm.addr(1)
        );

        uint256 userRecordBeforeTx = rociLottery.record(
            rociLottery.lottery(),
            hevm.addr(1)
        );

        uint256 userLotteryCurrencybeforeTx = rociLottery.lotteryCurrency(
            hevm.addr(1)
        );

        hevm.warp(1000);
        rociLottery.startLottery(100);

        rociLottery.playLottery(amount, hevm.addr(1));
        uint256 totalWagersAfterTx = rociLottery.totalWagers();

        uint256 userRecordAfterTx = rociLottery.record(
            rociLottery.lottery(),
            hevm.addr(1)
        );

        uint256 userSortitionSumTreeStakeAfterTx = rociLottery.chanceOf(
            hevm.addr(1)
        );

        uint256 userLotteryCurrencyAfterTx = rociLottery.lotteryCurrency(
            hevm.addr(1)
        );

        assertEq(userRecordBeforeTx + amount, userRecordAfterTx);
        assertEq(totalWagersBeforeTx + amount, totalWagersAfterTx);

        assertEq(
            userSortitionSumTreeStakeBeforeTx + amount,
            userSortitionSumTreeStakeAfterTx
        );

        assertEq(
            userLotteryCurrencybeforeTx - amount,
            userLotteryCurrencyAfterTx
        );
    }

    function testShouldFailIfLotteryStillActive() external {
        hevm.warp(1000);
        rociLottery.startLottery(100);

        hevm.expectRevert("lottery still active");
        rociLottery.draw();
    }

    function testShouldFailIfLotteryNotActiveAndNoActiveWager() external {
        hevm.expectRevert("no active wagers");
        rociLottery.draw();
    }

    struct Players {
        uint256 amount;
        address addr;
    }
    mapping(uint256 => Players) public players;

    function testDraw() external {
        hevm.warp(1000);
        rociLottery.startLottery(100);

        uint64[10] memory playersAmount = [
            1 ether,
            3 ether,
            2 ether,
            4 ether,
            2 ether,
            2 ether,
            3 ether,
            5 ether,
            2 ether,
            3 ether
        ];

        uint256 totalSum;

        for (uint256 i; i < playersAmount.length; i++) {
            sendETH(playersAmount[i], hevm.addr(i + 1));

            players[i].amount = playersAmount[i];
            players[i].addr = hevm.addr(i + 1);

            rociLottery.depositETH{value: players[i].amount}(players[i].addr);
            rociLottery.playLottery(players[i].amount, players[i].addr);

            totalSum += playersAmount[i];
        }

        hevm.warp(1600);
        rociLottery.draw();

        uint256 winnerBalance = rociLottery.lotteryCurrency(
            rociLottery.winner()
        );
        assertEq(totalSum, winnerBalance);

        for (uint256 i; i < playersAmount.length; i++) {
            if (players[i].addr != rociLottery.winner()) {
                assertEq(
                    rociLottery.getUserWagerForActiveLottery(players[i].addr),
                    0
                );
            }
        }
    }

    receive() external payable {}
}
