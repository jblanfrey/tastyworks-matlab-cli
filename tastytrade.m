classdef tastytrade < handle
  properties (Constant, Access=private)
    API = "https://api.tastyworks.com";
    USER = getenv('TW_USER');
    PASSWORD = getenv('TW_PASSWORD');
  end

  properties (SetAccess = immutable, GetAccess = private)
    SessionToken
    AccountNumber
  end

  properties (Access = private)
    AccountBalance_ = [];
    Positions_ = [];
    LiveOrders_ = [];
    Transactions_ = [];
  end

  properties (Dependent)
    AccountBalance
    Positions
    LiveOrders
    Transactions
    PandL
  end

  methods % Constructor
    function obj = tastytrade()
      obj.SessionToken = obj.fetchSessionToken;
      obj.AccountNumber = obj.fetchAccountNumber;
    end

    function token = fetchSessionToken(obj)
      input = struct('login', obj.USER, 'password', obj.PASSWORD);
      url = obj.API + "/sessions";
      method = matlab.net.http.RequestMethod.POST;
      header = matlab.net.http.HeaderField('Content-Type', 'application/json');
      body = matlab.net.http.MessageBody(input);
      request = matlab.net.http.RequestMessage(method,header,body);
      response = send(request,url);
      token = response.Body.Data.data.session_token;
    end

    function accountNumber = fetchAccountNumber(obj)
      url = obj.API + "/customers/me/accounts";
      response = fetchData(obj, url);
      accountNumber = response.Body.Data.data.items.account.account_number;
    end
  end % Constructor

  methods %GET SET
    function balance = get.AccountBalance(obj)
      if isempty(obj.AccountBalance_)
        obj.AccountBalance = [];
      end
      balance = obj.AccountBalance_;
    end

    function set.AccountBalance(obj, ~)
      url = obj.API + "/accounts/" + obj.AccountNumber + "/balances";
      response = fetchData(obj, url);
      obj.AccountBalance_ = response.Body.Data.data;
    end

    function positions = get.Positions(obj)
      if isempty(obj.Positions_)
        obj.Positions = [];
      end
      positions = obj.Positions_;
    end

    function set.Positions(obj, ~)
      url = obj.API + "/accounts/" + obj.AccountNumber + "/positions";
      response = fetchData(obj, url);
      obj.Positions_ = response.Body.Data.data.items;
    end

    function liveOrders = get.LiveOrders(obj)
      if isempty(obj.LiveOrders_)
        obj.LiveOrders = [];
      end
      liveOrders = obj.LiveOrders_;
    end

    function set.LiveOrders(obj, ~)
      url = obj.API + "/accounts/" + obj.AccountNumber + "/orders";
      response = fetchData(obj, url);
      obj.LiveOrders_ = response.Body.Data.data.items;
    end

    function transactions = get.Transactions(obj)
      if isempty(obj.Transactions_)
        obj.Transactions = [];
      end
      transactions = obj.Transactions_;
    end

    function set.Transactions(obj, ~)
      url = obj.API + "/accounts/" + obj.AccountNumber + "/transactions";
      response = fetchData(obj, url);
      obj.Transactions_ = response.Body.Data.data.items;
    end

    function pandl = get.PandL(obj)
      transactions = obj.Transactions;
      n = numel(transactions);
      Date = datetime.empty(n,0);
      Type = string.empty(n,0);
      NetValue = zeros(n,0);

      for k=1:n
        Date(k,1) = datetime(transactions{k}.transaction_date);
        Type(k,1) = transactions{k}.net_value_effect;
        NetValue(k,1) = str2double(transactions{k}.net_value);
      end

      TransactionsTable = timetable(Date,Type,NetValue);
      toRemove = Type=="None";
      TransactionsTable(toRemove,:) = [];
      debit = TransactionsTable.Type == "Debit";
      TransactionsTable.NetValue(debit) = -TransactionsTable.NetValue(debit);
      TransactionsTable = sortrows(TransactionsTable,'Date','ascend');

      [g,Year,Month] = findgroups(year(TransactionsTable.Date), month(TransactionsTable.Date));
      Total = splitapply(@sum, TransactionsTable.NetValue,g);

      pandl = table(Year, Month, Total);
    end
  end %GET SET

  methods
    function symbol = searchSymbol(obj, input)
      url = obj.API + "/symbols/search/" + input;
      response = fetchData(obj, url);
      symbol = response;
    end

    function optionChain = getOptionChain(obj, underlying)
      url = obj.API + "/option-chains/" + underlying + "/nested";
      response = fetchData(obj, url);
      optionChain = response.Body.Data.data.items;
    end

    function response = fetchData(obj, url)
      method = matlab.net.http.RequestMethod.GET;
      header = matlab.net.http.HeaderField('Content-Type', 'application/json',...
        'Authorization', obj.SessionToken);
      request = matlab.net.http.RequestMessage(method,header);
      response = send(request,url);
    end

    function response = executeOrder(obj)
      url = obj.API + "/accounts/" + obj.AccountNumber + "/orders";
      method = matlab.net.http.RequestMethod.POST;
      header = matlab.net.http.HeaderField('Content-Type', 'application/json',...
        'Authorization', obj.SessionToken);

%       leg = struct(...
%         "ticker", "DKNG",...
%         "quantity", 1,...
%         "expiry", datetime(2022,1,21),...
%         "strike", 20,...
%         "option_type", "P",...
%         "instrument_type", "Equity Option",...
%         "action", "Sell to Open");
      leg = struct(...
        "symbol", "DKNG 220121P00020000",...
        "quantity", 1,...
        "instrument_type", "Equity Option",...
        "action", "Sell to Open");
      order = struct( ...
        "order_type", "Limit",...
        "time_in_force", "Day",...
        "price", "1.00",...
        "price_effect", "Credit",...
        "source", "WBT",...
        "legs", leg);

      input = jsonencode(order);
      input = strrep(input, "_", "-");

      body = matlab.net.http.MessageBody(input);
      request = matlab.net.http.RequestMessage(method,header,body);
      response = send(request,url);
    end

    function streamer = getStreamer(obj)
      url = obj.API + "/quote-streamer-tokens";
      response = fetchData(obj, url);
      streamer = response;
    end
  end
end