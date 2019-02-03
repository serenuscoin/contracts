# @title Serenus Coin Factory contract
# @notice All issuer contracts are created by the factory
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b5

contract Issuer:
    def setup(_id: int128, _owner: address, _governor: address, _target_collateral_ratio: uint256): modifying

contract ERC20Serenus:
    def setMinterAddress(_issuer: address): modifying

NewIssuer: event({_id: indexed(int128), _issuer: indexed(address)})
    
issuer_template: public(address)
issuer_id: public(int128)

erc20_serenus: public(address)
governor: public(address)

owner: public(address)

@public
def __init__():
    self.owner = msg.sender
    self.issuer_template = 0xf7633BC2BcD08Fe900EE2413ed1b4f704209A51A
    self.erc20_serenus = 0x3052D1c679eA96500fda71A5Af1Bc2f5fAbC0dA0
    self.governor = 0x86C11371D65478c2E1FcdEe9fc4dBb0ebD6467A9

@public
def liquidate():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
    
@public
def setTemplateAddress(_address: address):
    assert msg.sender == self.owner
    self.issuer_template = _address

@public
def setERC20SerenusAddress(_address: address):
    assert msg.sender == self.owner
    self.erc20_serenus = _address

@public
def setGovernorAddress(_address: address):
    assert msg.sender == self.owner
    self.governor = _address

# @notice Create an issuer from the template
# @notice Send it a new id, the creator's address, a governor address and a target ratio
# @params A target collateral ratio
@public
def createIssuer(_target_collateral_ratio: uint256):
    self.issuer_id += 1    
    _new_issuer: address = create_with_code_of(self.issuer_template)
    Issuer(_new_issuer).setup(self.issuer_id, msg.sender, self.governor, _target_collateral_ratio)
    ERC20Serenus(self.erc20_serenus).setMinterAddress(_new_issuer)
    log.NewIssuer(self.issuer_id, _new_issuer)

