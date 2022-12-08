pragma solidity 0.8.6;

import './helpers/TestBaseWorkflowV1.sol';
import './helpers/TestBaseWorkflowV2.sol';
import '../V1Allocator.sol';

contract TestV1Allocation is TestBaseWorkflowV1, TestBaseWorkflowV2 {
  address _allocationSourceProjectOwner = address(456);
  address payable _allocationDDestinationProjectOwner = payable(address(0xf00ba5));

  uint256 _allocationSourceProjectId = 3;
  uint256 _allocationDestinationProjectId;

  ModStore _modStore;
  JBController controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundAccessConstraints[] _fundAccessConstraint;
  JBFundingCycleMetadata _metadata;
  IJBPaymentTerminal[] _terminals; // Default empty
  V1Allocator _v1Allocator;
  JBSplitsStore _jbSplitsStore;

  function setUp() public override(TestBaseWorkflowV1, TestBaseWorkflowV2) {
    TestBaseWorkflowV2.setUp();
    TestBaseWorkflowV1.setUp();

    _modStore = modStore();

    IJBDirectoryV3 v3Directory = IJBDirectoryV3(address(jbDirectory()));

    _v1Allocator = new V1Allocator(v3Directory);

    controller = jbController();

    _jbSplitsStore = jbSplitsStore();

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: 1000 * 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
      reservedRate: 5000, //50%
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: false,
      allowChangeToken: false,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: false,
      useDataSourceForRedeem: false,
      dataSource: address(0)
    });

    _terminals.push(jbETHPaymentTerminal());

    _fundAccessConstraint.push(JBFundAccessConstraints({
        terminal: jbETHPaymentTerminal(),
        token: jbLibraries().ETHToken(),
        distributionLimit: 2 ether,
        overflowAllowance: 0,
        distributionLimitCurrency: jbLibraries().ETH(),
        overflowAllowanceCurrency: jbLibraries().ETH()
    }));

    JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1); // Default empty
    
    // mimicing a v3 project launch since there was dependency issue with importing both v2 & v3 contract togethet since the almost every contract is the same
    evm.prank(_allocationDDestinationProjectOwner);
    _allocationDestinationProjectId = controller.launchProjectFor(
      _allocationDDestinationProjectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraint,
      _terminals,
      ''
    );

    PayoutMod[] memory _payOutMods = new PayoutMod[](1);
    _payOutMods[0] = PayoutMod({
        preferUnstaked: false,
        percent: 10000,
        lockedUntil: 0,
        beneficiary: _allocationDDestinationProjectOwner,
        allocator: _v1Allocator,
        projectId: uint56(_allocationDestinationProjectId)
    });

    evm.prank(_allocationSourceProjectOwner);
    _modStore.setPayoutMods(_allocationSourceProjectId, block.timestamp, _payOutMods);
  }

  function test_V1Allocation() public {
    JBETHPaymentTerminal _v3Terminal = jbETHPaymentTerminal();
    TerminalV1_1 _v1Terminal = terminal();
    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 1 ether);
    
    // pay project
    evm.prank(_user);
    _v1Terminal.pay{value: 1 ether}(
      _allocationSourceProjectId,
      _user,
      'Take my money',
       false
    );

    assertEq(_v1Terminal.balanceOf(_allocationSourceProjectId), 1 ether);
    
    // distribute thhe funds to another project
    evm.prank(_allocationSourceProjectOwner);
    _v1Terminal.tap(
      _allocationSourceProjectId,
      1 ether,
      0, // Currency
      0 // Min wei out
    );

    // deposit is 1 ether
    uint256 feeAmount = 1 ether - PRBMath.mulDiv(1 ether, 200, 200 + _v1Terminal.fee());

    assertEq(
      jbPaymentTerminalStore().balanceOf(_v3Terminal, _allocationDestinationProjectId), 1 ether - feeAmount
    );
  }
}