pragma solidity 0.8.6;

import './helpers/TestBaseWorkflow.sol';

contract TestV2Allocation is TestBaseWorkflow {
 address _allocationSourceProjectOwner = address(0xf00ba6);
 address payable _allocationDDestinationProjectOwner = payable(address(0xf00ba5));

  uint256 constant GROUP = 1;
  uint256 _allocationSourceProjectId;
  uint256 _allocationDestinationProjectId;

  JBController controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundAccessConstraints[] _fundAccessConstraint;
  JBFundingCycleMetadata _metadata;
  IJBPaymentTerminal[] _terminals; // Default empty
  V2Allocator _v2Allocator;
  JBSplitsStore _jbSplitsStore;

  function setUp() public override {
     super.setUp();

    controller = jbController();

    _v2Allocator = v2Allocator();

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
    
    evm.prank(_allocationSourceProjectOwner);
    _allocationSourceProjectId = controller.launchProjectFor(
      _allocationSourceProjectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraint,
      _terminals,
      ''
    );
    
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

   // setting splits
   JBSplit[] memory _splits = new JBSplit[](1);
   _splits[0] = JBSplit({
       preferClaimed: false,
       preferAddToBalance: true,
       projectId: _allocationDestinationProjectId,
       beneficiary: _allocationDDestinationProjectOwner,
       lockedUntil: 0,
       allocator: _v2Allocator,
       percent:  JBConstants.SPLITS_TOTAL_PERCENT
   });

    _groupedSplits[0] = JBGroupedSplits({
        group: GROUP,
        splits: _splits
    });

    (JBFundingCycle memory _currentFundingCycle, ) = controller.currentFundingCycleOf(_allocationSourceProjectId);

    evm.prank(_allocationSourceProjectOwner);
    _jbSplitsStore.set(_allocationSourceProjectId, _currentFundingCycle.configuration,  _groupedSplits);
  }

  function testV2Allocation() public {
    JBETHPaymentTerminal terminal = jbETHPaymentTerminal();
    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 1 ether);
    
    // pay project
    evm.prank(_user);
    terminal.pay{value: 1 ether}(
      _allocationSourceProjectId,
      1 ether,
      address(0),
      /* _beneficiary */
      _user,
      /* _minReturnedTokens */
      0,
      /* _preferClaimedTokens */
      false,
      /* _memo */
      'Take my money!',
      /* _delegateMetadata */
      new bytes(0)
    );

    assertEq(jbPaymentTerminalStore().balanceOf(terminal, _allocationSourceProjectId), 1 ether);
    
    // distribute thhe funds to another project
    evm.prank(_allocationSourceProjectOwner);
    terminal.distributePayoutsOf(
      _allocationSourceProjectId,
      1 ether,
      1, // Currency
      address(0), //token (unused)
      0, // Min wei out
      'v2 allocation' // Memo
    );

    assertEq(
      jbPaymentTerminalStore().balanceOf(terminal, _allocationDestinationProjectId),
      (1 ether * jbLibraries().MAX_FEE()) / (terminal.fee() + jbLibraries().MAX_FEE())
    );
  }
}