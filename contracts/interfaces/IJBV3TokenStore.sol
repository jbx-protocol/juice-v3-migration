// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol-v2/contracts/interfaces/IJBToken.sol';

// since importing v3 & v2 contract together give compilation issues because of same contract names & setFor isn't available in the v2 interface so using this custom interface
interface IJBV3TokenStore {
  function setFor(uint256 _projectId, IJBToken _token) external;
}
