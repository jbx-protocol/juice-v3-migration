pragma solidity 0.8.6;

import './helpers/TestBaseWorkflow.sol';

contract TestV2Allocation is TestBaseWorkflow {
 address _allocationSourceProjectOwner = address(0xf00ba6);
 address payable _allocationDDestinationProjectOwner = payable(address(0xf00ba5));

  uint256 constant DOMAIN = 1;
  uint256 constant GROUP = 1;
  uint256 _allocationSourceProjectId;
  uint256 _allocationDestinationProjectId;

  JBController controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundingCycleMetadata _metadata;
  JBFundAccessConstraints[] _fundAccessConstraints; // Default empty
  IJBPaymentTerminal[] _terminals; // Default empty
  V2Allocator _v2Allocator;
  JBSplitsStore _jbSplitsStore;

  function setUp() public override {
     super.setUp();

    controller = jbController();

    _v2Allocator = v2Allocator();

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

    JBGroupedSplits[] memory _groupedSplits; // Default empty
    
    evm.prank(_allocationSourceProjectOwner);
    _allocationSourceProjectId = controller.launchProjectFor(
      _allocationSourceProjectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraints,
      _terminals,
      ''
    );

    evm.prank(_allocationDDestinationProjectOwner);
    _allocationDestinationProjectId = controller.launchProjectFor(
      _allocationDDestinationProjectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraints,
      _terminals,
      ''
    );

   // setting splits
   JBSplit[] memory _splits;
   _splits[0] = JBSplit({
       preferClaimed: false,
       preferAddToBalance: false,
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

    _jbSplitsStore.set(_allocationSourceProjectId, DOMAIN, _groupedSplits);
  }
}