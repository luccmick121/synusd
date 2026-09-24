// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6 <0.9.0;

/**
 * @title StablecoinPadraoTether
 * @notice Porte moderno (Solidity 0.8.x) do contrato TetherToken (USDT) da Tether,
 *         mantendo os mesmos nomes de funções, eventos e mecânicas:
 *
 *         - ERC-20 com 6 decimais (padrão do USDT, não 18)
 *         - Emissão/resgate centralizados: issue() / redeem() (somente owner)
 *         - Pausa global: pause() / unpause()
 *         - Blacklist: addBlackList() / removeBlackList() / destroyBlackFunds()
 *         - Taxa de transferência configurável: setParams() (basis points + teto)
 *         - Migração para contrato novo: deprecate() + *_ByLegacy()
 *         - Transferência de posse em 2 passos: transferOwnership() -> acceptOwnership()
 *
 * @dev Diferenças intencionais em relação ao original (que usa Solidity 0.4.17 + SafeMath):
 *      1) Solidity 0.8+ já verifica overflow/underflow nativamente (SafeMath removido)
 *      2) Mensagens de erro em português para facilitar auditoria
 *      3) NatSpec e comentários explicando cada mecânica
 *
 *      AVISO IMPORTANTE: este é o "esqueleto técnico". Um stablecoin de verdade
 *      depende de RESERVAS off-chain e política de resgate — o contrato sozinho
 *      não garante paridade com dólar. Também NÃO use nome/símbolo "USDT"/"Tether"
 *      em produção (fraude/marca registrada). Use identidade própria.
 */
interface UpgradedStandardToken {
    function transferByLegacy(address from, address to, uint256 value) external returns (bool);
    function transferFromByLegacy(address sender, address from, address to, uint256 value) external returns (bool);
    function approveByLegacy(address from, address spender, uint256 value) external returns (bool);
}

contract StablecoinPadraoTether {
    // ------------------------------------------------------------------
    // Metadados do token (iguais em formato ao USDT)
    // ------------------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public decimals; // USDT usa 6

    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    // ------------------------------------------------------------------
    // Controles administrativos (no Tether tudo converge no owner)
    // ------------------------------------------------------------------
    address public owner;
    address public newOwner; // posse em 2 passos (igual Tether)

    bool public paused = false;
    bool public deprecated = false;
    address public upgradedAddress; // contrato sucessor após deprecate()

    uint256 public basisPointsRate = 0; // taxa padrão: 0 (desligada)
    uint256 public maximumFee = 0; // teto da taxa em unidades mínimas

    mapping(address => bool) public isBlackListed;

    // Limites máximos de taxa permitidos pelo setParams (igual USDT)
    uint256 private constant MAX_SETTABLE_BASIS_POINTS = 20; // 0,20%
    uint256 private constant MAX_SETTABLE_MAX_FEE = 50; // 50 tokens

    // ------------------------------------------------------------------
    // Eventos (mesmos nomes/assinaturas do TetherToken original)
    // ------------------------------------------------------------------
    event Issue(uint256 amount);
    event Redeem(uint256 amount);
    event Deprecate(address newAddress);
    event Params(uint256 feeBasisPoints, uint256 maxFee);

    event AddedBlackList(address indexed _user);
    event RemovedBlackList(address indexed _user);
    event DestroyedBlackFunds(address indexed _blackListedUser, uint256 _balance);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Pause();
    event Unpause();

    // ------------------------------------------------------------------
    // Modificadores
    // ------------------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Stablecoin: somente owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Stablecoin: contrato pausado");
        _;
    }

    modifier whenPaused() {
        require(paused, "Stablecoin: contrato nao pausado");
        _;
    }

    // ------------------------------------------------------------------
    // Constructor — mesmo padrão do TetherToken(_initialSupply, _name, _symbol, _decimals)
    // ------------------------------------------------------------------
    constructor(
        uint256 _initialSupply,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        totalSupply = _initialSupply;
        balances[owner] = _initialSupply;

        emit OwnershipTransferred(address(0), owner);
        emit Issue(_initialSupply);
    }

    // ------------------------------------------------------------------
    // Consultas básicas
    // ------------------------------------------------------------------
    function balanceOf(address _who) public view returns (uint256) {
        return balances[_who];
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    // ------------------------------------------------------------------
    // Cálculo de taxa (idêntico ao Tether)
    // fee = valor * basisPointsRate / 10000, limitado ao teto maximumFee
    // ------------------------------------------------------------------
    function calcFee(uint256 _value) public view returns (uint256) {
        uint256 fee = (_value * basisPointsRate) / 10000;
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        return fee;
    }

    // ------------------------------------------------------------------
    // ERC-20: transfer com blacklist, pausa, taxa e legado (deprecate)
    // ------------------------------------------------------------------
    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_to != address(0), "Stablecoin: destino zero");
        require(_value <= balances[msg.sender], "Stablecoin: saldo insuficiente");
        require(!isBlackListed[msg.sender], "Stablecoin: remetente na blacklist");
        require(!isBlackListed[_to], "Stablecoin: destino na blacklist");

        // Padrão do Tether: após deprecate(), as transferências são
        // encaminhadas ao contrato sucessor, mantendo a interface viva.
        if (deprecated) {
            return UpgradedStandardToken(upgradedAddress).transferByLegacy(msg.sender, _to, _value);
        }

        uint256 fee = calcFee(_value);
        uint256 sendAmount = _value - fee;

        balances[msg.sender] -= _value;
        balances[_to] += sendAmount;

        // A taxa vai para o owner (comportamento do USDT)
        if (fee > 0) {
            balances[owner] += fee;
            emit Transfer(msg.sender, owner, fee);
        }

        emit Transfer(msg.sender, _to, sendAmount);
        return true;
    }

    // ------------------------------------------------------------------
    // ERC-20: transferFrom com os mesmos controles
    // ------------------------------------------------------------------
    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_to != address(0), "Stablecoin: destino zero");
        require(_value <= balances[_from], "Stablecoin: saldo insuficiente");
        require(_value <= allowed[_from][msg.sender], "Stablecoin: allowance insuficiente");
        require(!isBlackListed[msg.sender], "Stablecoin: spender na blacklist");
        require(!isBlackListed[_from], "Stablecoin: remetente na blacklist");
        require(!isBlackListed[_to], "Stablecoin: destino na blacklist");

        if (deprecated) {
            return UpgradedStandardToken(upgradedAddress).transferFromByLegacy(msg.sender, _from, _to, _value);
        }

        uint256 fee = calcFee(_value);
        uint256 sendAmount = _value - fee;

        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        balances[_to] += sendAmount;

        if (fee > 0) {
            balances[owner] += fee;
            emit Transfer(_from, owner, fee);
        }

        emit Transfer(_from, _to, sendAmount);
        return true;
    }

    // ------------------------------------------------------------------
    // ERC-20: approve (encaminha ao sucessor se depreciado, como no Tether)
    // ------------------------------------------------------------------
    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        if (deprecated) {
            return UpgradedStandardToken(upgradedAddress).approveByLegacy(msg.sender, _spender, _value);
        }
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // ------------------------------------------------------------------
    // Emissão centralizada — como o Tether emite quando entra reserva
    // ------------------------------------------------------------------
    function issue(uint256 amount) public onlyOwner {
        totalSupply += amount;
        balances[owner] += amount;
        emit Issue(amount);
    }

    // ------------------------------------------------------------------
    // Resgate/queima — como o Tether queima quando sai reserva
    // ------------------------------------------------------------------
    function redeem(uint256 amount) public onlyOwner {
        require(totalSupply >= amount, "Stablecoin: supply insuficiente");
        require(balances[owner] >= amount, "Stablecoin: saldo do owner insuficiente");

        totalSupply -= amount;
        balances[owner] -= amount;
        emit Redeem(amount);
    }

    // ------------------------------------------------------------------
    // Configura taxa de transferência (limites iguais ao USDT)
    // ex.: setParams(10, 50*10**6) => 0,10% por transferência, teto de 50 tokens
    // ------------------------------------------------------------------
    function setParams(uint256 newBasisPoints, uint256 newMaxFee) public onlyOwner {
        require(newBasisPoints < MAX_SETTABLE_BASIS_POINTS, "Stablecoin: basis points acima do maximo (20)");
        require(newMaxFee < MAX_SETTABLE_MAX_FEE, "Stablecoin: max fee acima do limite (50 tokens)");

        basisPointsRate = newBasisPoints;
        maximumFee = newMaxFee * (uint256(10) ** decimals);

        emit Params(basisPointsRate, maximumFee);
    }

    // ------------------------------------------------------------------
    // Blacklist — congela endereços suspeitos (mecânica central do USDT)
    // ------------------------------------------------------------------
    function addBlackList(address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList(address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    // ------------------------------------------------------------------
    // Confisca e queima fundos de endereço na blacklist
    // ------------------------------------------------------------------
    function destroyBlackFunds(address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser], "Stablecoin: endereco nao esta na blacklist");

        uint256 dirtyFunds = balances[_blackListedUser];
        balances[_blackListedUser] = 0;
        totalSupply -= dirtyFunds;

        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    // ------------------------------------------------------------------
    // Deprecate — aponta para um contrato novo (estratégia de upgrade do Tether)
    // ------------------------------------------------------------------
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    // ------------------------------------------------------------------
    // Pausa global
    // ------------------------------------------------------------------
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }

    // ------------------------------------------------------------------
    // Posse em 2 passos (padrão do Tether):
    // owner chama transferOwnership(novo) -> novo chama acceptOwnership()
    // ------------------------------------------------------------------
    function transferOwnership(address newOwner_) public onlyOwner {
        newOwner = newOwner_;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner, "Stablecoin: voce nao e o novo owner");

        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        newOwner = address(0);
    }
}
