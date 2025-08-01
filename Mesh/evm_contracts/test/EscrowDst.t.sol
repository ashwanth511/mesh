// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/EscrowDst.sol";
import "../src/IFusionPlus.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowDstTest is Test {
    EscrowDst public escrowDst;
    MockToken public mockToken;
    
    address public maker = address(0x1);
    address public taker = address(0x2);
    address public other = address(0x3);
    address public accessTokenHolder = address(0x4);
    
    bytes32 public secret = bytes32("mysecret");
    bytes32 public orderHash;
    uint256 public amount = 1000 * 10**18; // 1000 tokens
    uint256 public safetyDeposit = 0.1 ether;
    
    IFusionPlus.Immutables public immutables;
    IFusionPlus.Timelocks public timelocks;
    
    event EscrowDstCreated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 hashlock,
        uint256 safetyDeposit
    );
    
    event EscrowDstFilled(
        bytes32 indexed orderHash,
        address indexed taker,
        bytes32 secret
    );
    
    event EscrowDstCancelled(
        bytes32 indexed orderHash,
        address indexed maker
    );
    
    event EscrowDstWithdrawn(
        bytes32 indexed orderHash,
        address indexed maker,
        uint256 amount
    );

    function setUp() public {
        // Deploy mock token
        mockToken = new MockToken("Mock Token", "MTK");
        
        // Deploy escrow contract
        escrowDst = new EscrowDst();
        
        // Setup test addresses
        vm.deal(maker, 20 ether);
        vm.deal(taker, 20 ether);
        vm.deal(other, 20 ether);
        vm.deal(accessTokenHolder, 20 ether);
        
        // Give tokens to taker
        mockToken.mint(taker, 10000 * 10**18);
        
        // Add access token holder
        escrowDst.addAccessTokenHolder(accessTokenHolder);
        
        // Setup timelocks
        timelocks = IFusionPlus.Timelocks({
            srcWithdrawal: block.timestamp + 1 hours,
            srcPublicWithdrawal: block.timestamp + 2 hours,
            srcCancellation: block.timestamp + 3 hours,
            dstWithdrawal: block.timestamp + 4 hours,
            dstPublicWithdrawal: block.timestamp + 5 hours,
            dstCancellation: block.timestamp + 6 hours
        });
        
        // Setup immutables
        immutables = IFusionPlus.Immutables({
            maker: maker,
            taker: taker,
            amount: amount,
            safetyDeposit: safetyDeposit,
            hashlock: keccak256(abi.encodePacked(secret)),
            timelocks: timelocks,
            token: address(mockToken),
            chainId: 1
        });
        
        // Generate order hash
        orderHash = keccak256(abi.encodePacked(
            maker,
            taker,
            amount,
            safetyDeposit,
            immutables.hashlock,
            timelocks.dstWithdrawal,
            timelocks.dstPublicWithdrawal,
            timelocks.dstCancellation,
            address(mockToken),
            1
        ));
    }

    function test_CreateEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Create escrow
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        // Verify escrow was created
        IFusionPlus.EscrowStatus memory status = escrowDst.escrowStatuses(orderHash);
        assertEq(status.isFilled, false);
        assertEq(status.isCancelled, false);
        assertEq(status.deployedAt, block.timestamp);
        assertEq(status.filledAt, 0);
        assertEq(status.cancelledAt, 0);
        
        // Verify immutables were stored
        IFusionPlus.Immutables memory stored = escrowDst.escrowImmutables(orderHash);
        assertEq(stored.maker, maker);
        assertEq(stored.taker, taker);
        assertEq(stored.amount, amount);
        assertEq(stored.safetyDeposit, safetyDeposit);
        assertEq(stored.hashlock, immutables.hashlock);
        assertEq(stored.token, address(mockToken));
        assertEq(stored.chainId, 1);
        
        vm.stopPrank();
    }

    function test_CreateEscrowDst_RevertIfAlreadyExists() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Create escrow first time
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        // Try to create again - should revert
        vm.expectRevert("Escrow already exists");
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowDst_RevertIfInsufficientDeposit() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Try to create with insufficient deposit
        vm.expectRevert("Insufficient safety deposit");
        escrowDst.createEscrowDst{value: safetyDeposit - 0.01 ether}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowDst_RevertIfInvalidAmount() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Create immutables with zero amount
        IFusionPlus.Immutables memory invalidImmutables = immutables;
        invalidImmutables.amount = 0;
        
        vm.expectRevert("Invalid amount");
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, invalidImmutables);
        
        vm.stopPrank();
    }

    function test_FillEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fill escrow as maker
        vm.prank(maker);
        escrowDst.fillEscrowDst(orderHash, secret);
        
        // Verify escrow was filled
        IFusionPlus.EscrowStatus memory status = escrowDst.escrowStatuses(orderHash);
        assertEq(status.isFilled, true);
        assertEq(status.filledAt, block.timestamp);
        assertEq(status.isCancelled, false);
        assertEq(status.cancelledAt, 0);
    }

    function test_FillEscrowDst_RevertIfNotMaker() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill as non-maker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        escrowDst.fillEscrowDst(orderHash, secret);
    }

    function test_FillEscrowDst_RevertIfInvalidSecret() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill with invalid secret
        vm.prank(maker);
        vm.expectRevert("Invalid secret");
        escrowDst.fillEscrowDst(orderHash, bytes32("wrongsecret"));
    }

    function test_FillEscrowDst_RevertIfAlreadyFilled() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fill escrow first time
        vm.prank(maker);
        escrowDst.fillEscrowDst(orderHash, secret);
        
        // Try to fill again
        vm.prank(maker);
        vm.expectRevert("Escrow already filled");
        escrowDst.fillEscrowDst(orderHash, secret);
    }

    function test_CancelEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past cancellation time
        vm.warp(block.timestamp + 7 hours);
        
        // Cancel escrow
        vm.prank(taker);
        escrowDst.cancelEscrowDst(orderHash);
        
        // Verify escrow was cancelled
        IFusionPlus.EscrowStatus memory status = escrowDst.escrowStatuses(orderHash);
        assertEq(status.isCancelled, true);
        assertEq(status.cancelledAt, block.timestamp);
        assertEq(status.isFilled, false);
        assertEq(status.filledAt, 0);
    }

    function test_CancelEscrowDst_RevertIfNotTaker() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past cancellation time
        vm.warp(block.timestamp + 7 hours);
        
        // Try to cancel as non-taker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        escrowDst.cancelEscrowDst(orderHash);
    }

    function test_CancelEscrowDst_RevertIfTooEarly() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to cancel before cancellation time
        vm.prank(taker);
        vm.expectRevert("Too early");
        escrowDst.cancelEscrowDst(orderHash);
    }

    function test_WithdrawEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past withdrawal time
        vm.warp(block.timestamp + 5 hours);
        
        // Withdraw escrow
        vm.prank(taker);
        escrowDst.withdrawEscrowDst(orderHash);
        
        // Verify tokens were returned to taker
        assertEq(mockToken.balanceOf(taker), 10000 * 10**18); // Original balance
    }

    function test_WithdrawEscrowDst_RevertIfNotTaker() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past withdrawal time
        vm.warp(block.timestamp + 5 hours);
        
        // Try to withdraw as non-taker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        escrowDst.withdrawEscrowDst(orderHash);
    }

    function test_WithdrawEscrowDst_RevertIfTooEarly() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to withdraw before withdrawal time
        vm.prank(taker);
        vm.expectRevert("Too early");
        escrowDst.withdrawEscrowDst(orderHash);
    }

    function test_PublicWithdrawEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past public withdrawal time
        vm.warp(block.timestamp + 6 hours);
        
        // Public withdraw escrow
        vm.prank(other);
        escrowDst.publicWithdrawEscrowDst(orderHash);
        
        // Verify tokens were returned to taker
        assertEq(mockToken.balanceOf(taker), 10000 * 10**18); // Original balance
    }

    function test_PublicWithdrawEscrowDst_RevertIfTooEarly() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        escrowDst.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to public withdraw before public withdrawal time
        vm.prank(other);
        vm.expectRevert("Too early");
        escrowDst.publicWithdrawEscrowDst(orderHash);
    }

    function test_AddAccessTokenHolder() public {
        address newHolder = address(0x5);
        
        vm.prank(address(escrowDst.owner()));
        escrowDst.addAccessTokenHolder(newHolder);
        
        assertTrue(escrowDst.accessTokenHolders(newHolder));
    }

    function test_RemoveAccessTokenHolder() public {
        address holderToRemove = accessTokenHolder;
        
        vm.prank(address(escrowDst.owner()));
        escrowDst.removeAccessTokenHolder(holderToRemove);
        
        assertFalse(escrowDst.accessTokenHolders(holderToRemove));
    }

    function test_RescueTokens() public {
        // Send some tokens to the contract
        mockToken.mint(address(escrowDst), 1000 * 10**18);
        
        uint256 initialBalance = mockToken.balanceOf(address(escrowDst));
        assertGt(initialBalance, 0);
        
        // Fast forward past rescue delay
        vm.warp(block.timestamp + 31 days);
        
        // Rescue tokens
        vm.prank(address(escrowDst.owner()));
        escrowDst.rescueTokens(address(mockToken));
        
        // Verify tokens were rescued
        assertEq(mockToken.balanceOf(address(escrowDst)), 0);
    }

    function test_RescueTokens_RevertIfTooEarly() public {
        // Send some tokens to the contract
        mockToken.mint(address(escrowDst), 1000 * 10**18);
        
        // Try to rescue before delay
        vm.prank(address(escrowDst.owner()));
        vm.expectRevert("Too early");
        escrowDst.rescueTokens(address(mockToken));
    }

    function test_RescueTokens_RevertIfNotOwner() public {
        // Send some tokens to the contract
        mockToken.mint(address(escrowDst), 1000 * 10**18);
        
        // Fast forward past rescue delay
        vm.warp(block.timestamp + 31 days);
        
        // Try to rescue as non-owner
        vm.prank(other);
        vm.expectRevert();
        escrowDst.rescueTokens(address(mockToken));
    }
} 