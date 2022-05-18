function [price, TT] = takeProfitPrice(t, symbol)

  % price: price at which to sell the option to get 50% profit.
  % useful to know when the option was rolled for a profit.

  arguments
    t tastytrade
    symbol(1,1) string = "JPM";
  end

TT = cell.empty;
optionPrice = 0;

for index = 1:numel(t.Transactions)
  if isfield(t.Transactions{index}, 'underlying_symbol')
    if t.Transactions{index}.underlying_symbol == symbol
      TT{end+1} = t.Transactions{index};
       if t.Transactions{index}.value_effect == "Debit"
        optionPrice = optionPrice - str2double(t.Transactions{index}.price);
      else
        optionPrice = optionPrice + str2double(t.Transactions{index}.price);
      end
    end
  end
end


price = table(optionPrice * (1-[0.2; 0.4; 0.5]), ["2 days"; "7 days"; "14 days"]);
price.Properties.VariableNames = ["Sell Option at"; "Sell within"];


