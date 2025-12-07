create database retail;
desc `customer_profiles-1-1714027410 (1)`;
-- fixing the primary key of each column having types error
alter table `customer_profiles-1-1714027410 (1)`
change ï»¿CustomerID CustomerID int;
alter table `product_inventory-1-1714027438 (1)`
rename column ï»¿ProductID to ProductId;
desc `sales_transaction-1714027462 (1)`;
alter table `sales_transaction-1714027462 (1)`
rename column ï»¿TransactionID to TransactionId;
-- always spend time to understand the dataset
select * from `customer_profiles-1-1714027410 (1)`;
select * from `product_inventory-1-1714027438 (1)`;
select * from `sales_transaction-1714027462 (1)`;
select count(*) from `sales_transaction-1714027462 (1)`;

-- identify and eliminate duplicate records from the sales_transaction-1714027462 (1)
-- table to ensure clean and accueate data analysis
select
	transactionid,
    count(*) as trxn_count
from `sales_transaction-1714027462 (1)`
group by 1
having trxn_count > 1;

select * from `sales_transaction-1714027462 (1)`
where transactionid = 5000;

create table sales_trxn_unique as 
select
	distinct * 
from `sales_transaction-1714027462 (1)`;

select * from sales_trxn_unique
where TransactionId = 5000;

drop table `sales_transaction-1714027462 (1)`;

-- ensure consistency between sales prices in the sales_trxn_unique data
-- and the product_inventory

select
	s.productID,
    s.transactionID,
    s.price as trxnprice,
    p.price as inventoryprice
from sales_trxn_unique s
join `product_inventory-1-1714027438 (1)` p on s.ProductId = p.ProductID
where p.price != s.price;

SET SQL_SAFE_UPDATES = 0;

select * from sales_trxn_unique where ProductID = 51;
update sales_trxn_unique
set price = 93.12
where productID = 51;    

update sales_trxn_unique as s
set price = (
	select
		p.price
    from `product_inventory-1-1714027438 (1)` as p
    where s.ProductID = p.ProductId
)
where s.ProductID in (
	select ProductID from `product_inventory-1-1714027438 (1)` as p
    where s.Price <> p.Price
);       
    
-- finding missing values and fix with null 

desc `customer_profiles-1-1714027410 (1)`;
select distinct location from `customer_profiles-1-1714027410 (1)`;  -- we check it one by one each column and only location column havre null values
select count(*) from `customer_profiles-1-1714027410 (1)` where Location = '';

-- update empty values with unknown
set sql_safe_updates = 0;
update `customer_profiles-1-1714027410 (1)`
set location = "Unknown"
WHERE Location = '' OR Location IS NULL OR Location = ' ';

select distinct Location from `customer_profiles-1-1714027410 (1)`;

desc sales_trxn_unique ;
-- Create a separate table and change the data type of the date column as it is in TEXT format and name it as you wish to.
-- Remove the original table from the database.
-- Change the name of the new table and replace it with the original name of the table.

create table sales_trxn_backup as
select *,
cast(transactiondate as DATE) as new_trxn_date
from sales_trxn_unique;

select * from sales_trxn_backup;
select * from sales_trxn_unique;
desc sales_trxn_backup;

drop table sales_trxn_unique;
alter table sales_trxn_backup
rename to sales_transaction;
alter table sales_transaction
drop column TransactionDate;
alter table sales_transaction
rename column new_trxn_date to Transactiondate;
select * from sales_transaction;

-- analyze which products are generating the most sales and units sold.
select * from sales_transaction;

select 
	productid,
    round(sum(quantitypurchased * price),0) as totalsales,
    sum(quantitypurchased) as totalunitsold
from sales_transaction
group by ProductID
order by totalsales desc;

-- Write a SQL query to count the number of transactions per customer to understand purchase frequency.

select 
	customerid,
    count(*) as transaction_count
from sales_transaction
group by CustomerID 
order by transaction_count desc;  

-- evaluate which categories generate the most revenue and totalunitsold
select
	p.category,
    round(sum(s.quantitypurchased * s.price),0) as totalrevenue,
    sum(s.quantitypurchased) as totalunitsold
from `product_inventory-1-1714027438 (1)` p
join sales_transaction s on p.productid = s.ProductID
group by p.Category
order by totalrevenue desc;   

-- identify the top 10 products based on total revenue generated
select * from sales_transaction;
select
	productid,
    sum(quantitypurchased * price) as totalrevenue
from sales_transaction
group by ProductID
order by totalrevenue desc
limit 10;

-- find the bottom 10 products with the lowest units sold
select * from sales_transaction;
select 
	ProductID,
	sum(quantitypurchased) as totalunitsold
from sales_transaction
group by ProductID
having sum(QuantityPurchased) > 0
order by totalunitsold asc
limit 10;  

-- identify the sales trend to understand the revenue pattern of the company.
desc sales_transaction;  

select
	cast(transactiondate as date) as datetrans,
    count(*) as transaction_count,
    sum(quantitypurchased) as totalunitsold,
    round(sum(quantitypurchased * price),0) as totalrevenue
from sales_transaction
group by Transactiondate
order by datetrans desc;    

-- analyze how total monthly sales are growing or decline over time
select * from sales_transaction;

with monthly_sales as (
	select
		extract(month from transactiondate) as month,
        round(sum(quantitypurchased * price),0) as totalsales
    from sales_transaction
    group by extract(month from transactiondate)
)    
select 
	month,
	totalsales,
	lag(totalsales) over(order by month) as previous_month_sales,
    round(((totalsales) - lag(totalsales) over(order by month)) / lag(totalsales) over(order by month) * 100,2) as mom_growth_percentage
from monthly_sales
order by month;    


-- -- Product category sales trend analysis
WITH monthly_sales AS (
  SELECT p.Category, EXTRACT(MONTH FROM s.TransactionDate) AS Month, round(SUM(s.QuantityPurchased * s.Price),2) AS TotalSales
  FROM sales_transaction s
  JOIN `product_inventory-1-1714027438 (1)` p ON s.ProductID = p.ProductID
  GROUP BY p.Category, EXTRACT(MONTH FROM s.TransactionDate)
)
SELECT Category, Month, TotalSales,
       LAG(TotalSales) OVER(PARTITION BY Category ORDER BY Month) AS PreviousMonthSales,
       ROUND(((TotalSales - LAG(TotalSales) OVER(PARTITION BY Category ORDER BY Month)) / LAG(TotalSales) OVER(PARTITION BY Category ORDER BY Month)) * 100, 2) AS MoMGrowthRate
FROM monthly_sales
ORDER BY Category, Month;


-- identify customer who purchase frequently and spend significantly
select * from sales_transaction;

select
	customerid,
    count(*) as numberoftransaction,
    round(sum(quantitypurchased * price),0) as totalspent
from sales_transaction
group by customerid
having totalspent > 1000 and numberoftransaction > 10
order by totalspent desc;  

-- Customer segmentation based on purchase frequency and value
WITH customer_purchases AS (
  SELECT CustomerID, COUNT(*) AS PurchaseFrequency, SUM(QuantityPurchased * Price) AS TotalValue
  FROM sales_transaction
  GROUP BY CustomerID
)
SELECT CustomerID, PurchaseFrequency, TotalValue,
       CASE
         WHEN PurchaseFrequency > 10 AND TotalValue > 1000 THEN 'High Value'
         WHEN PurchaseFrequency > 5 AND TotalValue > 500 THEN 'Medium Value'
         ELSE 'Low Value'
       END AS CustomerSegment
FROM customer_purchases;

    
--  describes the number of transaction along with the total amount spent by each customer, which will help us understand the customers who are occasional customers or have low purchase frequency in the company
select 
    customerid,
    count(transactionid) as numberoftransactions,
    sum(quantitypurchased * price) as totalspent
from
    sales_transaction
group by
     customerid
having
    numberoftransactions <= 2
order by
    numberoftransactions asc, totalspent desc; 
    
-- describes the total number of purchases made by each customer against each productID to understand the repeat customers in the company.
select
	customerid,
    productid,
    count(transactionid) as timepurchased
from sales_transaction
group by customerid,productid
having timepurchased > 1
order by timepurchased desc;    

-- describes the duration between the first and the last purchase of the customer in that particular company to understand the loyalty of the customer.
select
    customerid,
    min(transactiondate) as firstpurchase,
    max(transactiondate) as lastpurchase,
    datediff(max(transactiondate), min(transactiondate)) as daysbetweenpurchases
from
    sales_transaction
group by
    customerid
having
    daysbetweenpurchases > 0
order by    
    daysbetweenpurchases desc;                

-- customer who have not purchase recently
SELECT c.CustomerID, MAX(s.TransactionDate) AS LastPurchaseDate
FROM `customer_profiles-1-1714027410 (1)` c
LEFT JOIN sales_transaction s ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID
HAVING MAX(s.TransactionDate) < DATE_SUB(CURDATE(), INTERVAL(60) day);


-- group cudstomer into segment based on the toral quantity of products they purchased
SELECT 
    CustomerSegment, 
    COUNT(*) AS NumberOfCustomers
FROM (
    SELECT
        s.CustomerID, 
        SUM(s.QuantityPurchased) AS TotalQuantity,
        CASE
            WHEN SUM(s.QuantityPurchased) BETWEEN 1 AND 10 THEN 'Low'
            WHEN SUM(s.QuantityPurchased) BETWEEN 11 AND 30 THEN 'Med'
            ELSE 'High'
        END AS CustomerSegment
    FROM
        sales_transaction s 
    JOIN 
        `customer_profiles-1-1714027410 (1)` c ON s.CustomerID = c.CustomerID
    GROUP BY
        s.CustomerID
) AS Customer_segment
GROUP BY 
    CustomerSegment;

-- customer retention rate
WITH customer_purchases AS (
  SELECT CustomerID, MIN(TransactionDate) AS FirstPurchase, MAX(TransactionDate) AS LastPurchase
  FROM sales_transaction
  GROUP BY CustomerID
)
SELECT COUNT(*) AS TotalCustomers, 
       SUM(CASE WHEN DATEDIFF(LastPurchase, FirstPurchase) > 365 THEN 1 ELSE 0 END) AS RetainedCustomers,
       ROUND(SUM(CASE WHEN DATEDIFF(LastPurchase, FirstPurchase) > 365 THEN 1 ELSE 0 END) / COUNT(*), 2) AS RetentionRate
FROM customer_purchases;

-- gender wise product preference
SELECT c.Gender, p.Category, COUNT(*) AS PurchaseCount
FROM sales_transaction s
JOIN `customer_profiles-1-1714027410 (1)` c ON s.CustomerID = c.CustomerID
JOIN `product_inventory-1-1714027438 (1)` p ON s.ProductID = p.ProductID
GROUP BY c.Gender, p.Category
ORDER BY 3 DESC;

-- age group wise spending
SELECT 
    CASE 
        WHEN Age BETWEEN 18 AND 25 THEN '18-25'
        WHEN Age BETWEEN 26 AND 35 THEN '26-35'
        WHEN Age BETWEEN 36 AND 50 THEN '36-50'
        ELSE '50+'
    END AS AgeGroup,
    round(SUM(s.QuantityPurchased * s.Price),2) AS TotalSpending
FROM sales_transaction s
JOIN `customer_profiles-1-1714027410 (1)` c ON s.CustomerID = c.CustomerID
GROUP BY AgeGroup
ORDER BY SUM(s.QuantityPurchased * s.Price) DESC;

-- best selling product location wise
SELECT c.Location, p.ProductName, SUM(s.QuantityPurchased) AS TotalSold
FROM sales_transaction s
JOIN `customer_profiles-1-1714027410 (1)` c ON s.CustomerID = c.CustomerID
JOIN `product_inventory-1-1714027438 (1)` p ON s.ProductID = p.ProductID
GROUP BY c.Location, p.ProductName
ORDER BY c.location , SUM(s.QuantityPurchased) desc;

-- stock risk analysis (products selling fast but low stock)
SELECT p.ProductName, SUM(s.QuantityPurchased) AS TotalSold, p.StockLevel
FROM sales_transaction s
JOIN `product_inventory-1-1714027438 (1)` p ON s.ProductID = p.ProductID
GROUP BY p.ProductName, p.StockLevel
HAVING p.StockLevel < 50
ORDER BY SUM(s.QuantityPurchased) desc;