// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '../JBV3TokenDeployer.sol';
import 'forge-std/Script.sol';


contract Deploy_JB_V3_Token_Deployer_On_Mainnet is Script {
    
    IProjects v1ProjectDirectory = IProjects(0x9b5a4053FfBB11cA9cd858AAEE43cc95ab435418);
    IJBProjects v3_v2_ProjectDirectory = IJBProjects(0xD8B4359143eda5B2d763E127Ed27c77addBc47d3);
    JBV3TokenDeployer v3TokenDeployer;

    function run() external {
      vm.startBroadcast();

      v3TokenDeployer = new JBV3TokenDeployer(v3_v2_ProjectDirectory, v1ProjectDirectory);
      console.log(address(v3TokenDeployer));
    }
}