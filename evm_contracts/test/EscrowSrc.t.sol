// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/EscrowSrc.sol";
import "../src/IFusionPlus.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowSrcTest is Test {
    EscrowSrc public escrowSrc;
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
    
    event EscrowSrcCreated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 hashlock,
        uint256 safetyDeposit
    );
    
    event EscrowSrcFilled(
        bytes32 indexed orderHash,
        address indexed taker,
        bytes32 secret
    );
    
    event EscrowSrcCancelled(
        bytes32 indexed orderHash,
        address indexed maker
    );
    
    event EscrowSrcWithdrawn(
        bytes32 indexed orderHash,
        address indexed maker,
        uint256 amount
    );

    function setUp() public {
        // Deploy mock token
        mockToken = new MockToken("Mock Token", "MTK");
        
        // Deploy escrow contract
        escrowSrc = new EscrowSrc();
        
        // Setup test addresses
        vm.deal(maker, 20 ether);
        vm.deal(taker, 20 ether);
        vm.deal(other, 20 ether);
        vm.deal(accessTokenHolder, 20 ether);
        
        // Give tokens to maker
        mockToken.mint(maker, 10000 * 10**18);
        
        // Add access token holder
        escrowSrc.addAccessTokenHolder(accessTokenHolder);
        
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
            timelocks.srcWithdrawal,
            timelocks.srcPublicWithdrawal,
            timelocks.srcCancellation,
            address(mockToken),
            1
        ));
    }

    function test_CreateEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Create escrow
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        // Verify escrow was created
        IFusionPlus.EscrowStatus memory status = escrowSrc.escrowStatuses(orderHash);
        assertEq(status.isFilled, false);
        assertEq(status.isCancelled, false);
        assertEq(status.deployedAt, block.timestamp);
        assertEq(status.filledAt, 0);
        assertEq(status.cancelledAt, 0);
        
        // Verify immutables were stored
        IFusionPlus.Immutables memory stored = escrowSrc.escrowImmutables(orderHash);
        assertEq(stored.maker, maker);
        assertEq(stored.taker, taker);
        assertEq(stored.amount, amount);
        assertEq(stored.safetyDeposit, safetyDeposit);
        assertEq(stored.hashlock, immutables.hashlock);
        assertEq(stored.token, address(mockToken));
        assertEq(stored.chainId, 1);
        
        vm.stopPrank();
    }

    function test_CreateEscrowSrc_RevertIfAlreadyExists() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Create escrow first time
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        // Try to create again - should revert
        vm.expectRevert("Escrow already exists");
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowSrc_RevertIfInsufficientDeposit() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Try to create with insufficient deposit
        vm.expectRevert("Insufficient safety deposit");
        escrowSrc.createEscrowSrc{value: safetyDeposit - 0.01 ether}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowSrc_RevertIfInvalidAmount() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Create immutables with zero amount
        IFusionPlus.Immutables memory invalidImmutables = immutables;
        invalidImmutables.amount = 0;
        
        vm.expectRevert("Invalid amount");
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, invalidImmutables);
        
        vm.stopPrank();
    }

    function test_FillEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fill escrow as taker
        vm.prank(taker);
        escrowSrc.fillEscrowSrc(orderHash, secret);
        
        // Verify escrow was filled
        IFusionPlus.EscrowStatus memory status = escrowSrc.escrowStatuses(orderHash);
        assertEq(status.isFilled, true);
        assertEq(status.filledAt, block.timestamp);
        assertEq(status.isCancelled, false);
        assertEq(status.cancelledAt, 0);
    }

    function test_FillEscrowSrc_RevertIfNotTaker() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill as non-taker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        escrowSrc.fillEscrowSrc(orderHash, secret);
    }

    function test_FillEscrowSrc_RevertIfInvalidSecret() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill with invalid secret
        vm.prank(taker);
        vm.expectRevert("Invalid secret");
        escrowSrc.fillEscrowSrc(orderHash, bytes32("wrongsecret"));
    }

    function test_FillEscrowSrc_RevertIfAlreadyFilled() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fill escrow first time
        vm.prank(taker);
        escrowSrc.fillEscrowSrc(orderHash, secret);
        
        // Try to fill again
        vm.prank(taker);
        vm.expectRevert("Escrow already filled");
        escrowSrc.fillEscrowSrc(orderHash, secret);
    }

    function test_CancelEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past cancellation time
        vm.warp(block.timestamp + 4 hours);
        
        // Cancel escrow
        vm.prank(maker);
        escrowSrc.cancelEscrowSrc(orderHash);
        
        // Verify escrow was cancelled
        IFusionPlus.EscrowStatus memory status = escrowSrc.escrowStatuses(orderHash);
        assertEq(status.isCancelled, true);
        assertEq(status.cancelledAt, block.timestamp);
        assertEq(status.isFilled, false);
        assertEq(status.filledAt, 0);
    }

    function test_CancelEscrowSrc_RevertIfNotMaker() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past cancellation time
        vm.warp(block.timestamp + 4 hours);
        
        // Try to cancel as non-maker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        escrowSrc.cancelEscrowSrc(orderHash);
    }

    function test_CancelEscrowSrc_RevertIfTooEarly() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to cancel before cancellation time
        vm.prank(maker);
        vm.expectRevert("Too early");
        escrowSrc.cancelEscrowSrc(orderHash);
    }

    function test_WithdrawEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past withdrawal time
        vm.warp(block.timestamp + 2 hours);
        
        // Withdraw escrow
        vm.prank(maker);
        escrowSrc.withdrawEscrowSrc(orderHash);
        
        // Verify tokens were returned to maker
        assertEq(mockToken.balanceOf(maker), 10000 * 10**18); // Original balance
    }

    function test_WithdrawEscrowSrc_RevertIfNotMaker() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past withdrawal time
        vm.warp(block.timestamp + 2 hours);
        
        // Try to withdraw as non-maker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        escrowSrc.withdrawEscrowSrc(orderHash);
    }

    function test_WithdrawEscrowSrc_RevertIfTooEarly() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to withdraw before withdrawal time
        vm.prank(maker);
        vm.expectRevert("Too early");
        escrowSrc.withdrawEscrowSrc(orderHash);
    }

    function test_PublicWithdrawEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past public withdrawal time
        vm.warp(block.timestamp + 3 hours);
        
        // Public withdraw escrow
        vm.prank(other);
        escrowSrc.publicWithdrawEscrowSrc(orderHash);
        
        // Verify tokens were returned to maker
        assertEq(mockToken.balanceOf(maker), 10000 * 10**18); // Original balance
    }

    function test_PublicWithdrawEscrowSrc_RevertIfTooEarly() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        escrowSrc.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to public withdraw before public withdrawal time
        vm.prank(other);
        vm.expectRevert("Too early");
        escrowSrc.publicWithdrawEscrowSrc(orderHash);
    }

    function test_AddAccessTokenHolder() public {
        address newHolder = address(0x5);
        
        vm.prank(address(escrowSrc.owner()));
        escrowSrc.addAccessTokenHolder(newHolder);
        
        assertTrue(escrowSrc.accessTokenHolders(newHolder));
    }

    function test_RemoveAccessTokenHolder() public {
        address holderToRemove = accessTokenHolder;
        
        vm.prank(address(escrowSrc.owner()));
        escrowSrc.removeAccessTokenHolder(holderToRemove);
        
        assertFalse(escrowSrc.accessTokenHolders(holderToRemove));
    }

    function test_RescueTokens() public {
        // Send some tokens to the contract
        mockToken.mint(address(escrowSrc), 1000 * 10**18);
        
        uint256 initialBalance = mockToken.balanceOf(address(escrowSrc));
        assertGt(initialBalance, 0);
        
        // Fast forward past rescue delay
        vm.warp(block.timestamp + 31 days);
        
        // Rescue tokens
        vm.prank(address(escrowSrc.owner()));
        escrowSrc.rescueTokens(address(mockToken));
        
        // Verify tokens were rescued
        assertEq(mockToken.balanceOf(address(escrowSrc)), 0);
    }

    function test_RescueTokens_RevertIfTooEarly() public {
        // Send some tokens to the contract
        mockToken.mint(address(escrowSrc), 1000 * 10**18);
        
        // Try to rescue before delay
        vm.prank(address(escrowSrc.owner()));
        vm.expectRevert("Too early");
        escrowSrc.rescueTokens(address(mockToken));
    }

    function test_RescueTokens_RevertIfNotOwner() public {
        // Send some tokens to the contract
        mockToken.mint(address(escrowSrc), 1000 * 10**18);
        
        // Fast forward past rescue delay
        vm.warp(block.timestamp + 31 days);
        
        // Try to rescue as non-owner
        vm.prank(other);
        vm.expectRevert();
        escrowSrc.rescueTokens(address(mockToken));
    }
} 