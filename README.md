# D2C Revenue Growth Simulator

An interactive what-if tool for modeling revenue growth levers using real e-commerce transaction data.

## Problem Statement

A D2C/online gift-ware retailer wants to understand which growth levers (customer acquisition, average order value (AOV), purchase frequency, or retention) would have the biggest impact on revenue, but has no tool to test these scenarios before committing budget. Using two years of real transaction history, this project builds the retailer's baseline growth model from actual customer behavior, then creates an interactive simulator that lets a decision-maker adjust key levers (e.g. "what if AOV increases 10%?" or "what if retention improves 5%?") and instantly see the projected revenue impact.

## Dataset

**Source:** [Online Retail II — UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii)

A real online retail transaction dataset containing all transactions of a UK-based, registered, non-store online retailer between December 1, 2009 and December 9, 2011 (the UCI page mentions September 2011, but the data itself, checked in this project, runs to Dec 9, 2011). The company mainly sells unique all-occasion gift-ware, and many of its customers are wholesalers. Licensed under CC BY 4.0.

- **Raw size:** 1,067,371 transaction line items, 9 columns
- **Time span:** Dec 2009 – Dec 2011
- **Coverage:** 5,942 unique customers, 5,305 unique products, 43 countries

## Data Cleaning Summary

**Starting point:** 1,067,371 raw transaction line items, combined from two sheets of the raw dataset.

**Cleaning steps applied, in order:**

| Step | Action | Rows Removed | Rows Remaining | Why |
|---|---|---|---|---|
| 1 | Removed rows with negative Price | 5 | 1,067,366 | These were internal "bad debt" accounting adjustments (Description: "Adjust bad debt"), not real customer sales. Including them would distort revenue calculations |
| 2 | Removed cancelled invoices (Invoice starting with 'C') | 19,494 | 1,047,872 | Cancelled orders never resulted in a completed sale. The simulator models real purchase behavior, not cancelled ones |
| 3 | Removed remaining negative Quantity rows | 3,457 | 1,044,415 | Negative quantity indicates a return/adjustment even when not formally marked as cancelled, so it is not a genuine completed purchase |
| 4 | Removed non-product StockCodes (POST, DOT, M, D, S, ADJUST, AMAZONFEE, CRUK, etc.) | 4,337 | 1,040,078 | These are postage charges, bank fees, manual entries, and discounts, not actual gift-ware product sales, so they would inflate/distort revenue and AOV |
| 5 | Removed rows with missing Customer ID | 237,083 | 802,995 | The simulator is built on customer-level behavior (retention, purchase frequency). Transactions with no customer identity can't feed that model |
| 6 | Removed exact duplicate rows | 11,930 | 791,065 | Exact duplicates are data entry errors, not genuine repeat purchases. Counting them would inflate revenue and order counts |

**Final cleaned dataset:** 791,065 rows (a 25.9% reduction from the raw data), 0 missing values across all columns.

**Additional fixes applied:**
- Converted `InvoiceDate` from text to proper `datetime` format, required for any time-based/monthly analysis
- Converted `Customer ID` from float to integer, cleaner for grouping/joining operations
- Added a derived `Revenue` column (`Quantity × Price`), needed for all revenue calculations going forward

**Key resulting stats:**
- Date range confirmed: Dec 1, 2009 – Dec 9, 2011
- 5,856 unique customers remain (down from 5,942 in raw data; the rest only had cancelled, non-product, or unidentified transactions)
- Total clean revenue: **£17,391,102.89**

**Known limitation:** This cleaned dataset only reflects behavior from identifiable, registered customers with completed purchases. Guest/unidentified transactions (~23% of raw rows) are excluded, meaning the simulator understates the retailer's true total revenue, but it gives a reliable base for customer-level modeling (retention, frequency, AOV), which is what this project's growth model depends on.

## Baseline Growth Metrics

Using SQL (MySQL), the cleaned transaction data was analyzed to extract the real behavioral metrics that calibrate the growth simulator. These metrics form the foundation of the growth model: **Revenue = Active Customers × Purchase Frequency × Average Order Value**, combined with a retention rate that governs how the customer base evolves over time.

### Metric 1: Monthly Revenue Trend

Revenue ranged from approximately £440K to £1.16M per month across the 2-year period, with clear seasonality: revenue consistently peaks in **November** each year (holiday gift-buying season) and dips in **January/February** (post-holiday lull). December 2011 shows an artificially low figure because the dataset's coverage ends on Dec 9, 2011 (a partial month), not due to any real business decline.

### Metric 2: Average Order Value (AOV)

AOV ranged from roughly **£400 to £550** for most months, with notable spikes in December (£626 in 2010, £659 in 2011). This suggests that while order *volume* drops in December, the orders that do happen tend to be larger, likely reflecting last-minute bulk/wholesale purchases. Baseline AOV used for the simulator: **~£470** (representative average across the full period).

### Metric 3: Purchase Frequency

Customers placed an average of **1.3 to 1.6 orders per month** when active, with the ratio fairly stable throughout the dataset. Frequency peaks slightly in November (holiday season, customers placing a second order for extra gifts). This relatively tight range suggests frequency has limited room for aggressive growth compared to other levers like retention or AOV.

### Metric 4: Monthly Customer Retention Rate

Calculated using a SQL CTE with a self-join pattern: for each month, the percentage of customers who also purchased in the following month.

Retention consistently ranged between **35% and 45%** month-over-month across most of the dataset, averaging approximately **38-39%**.

**Data limitation note:** November 2011 (22.32%) and December 2011 (0.00%) show artificially low retention because the dataset's coverage window ends Dec 9, 2011, so there is insufficient or no "following month" data to measure against for these two months. These two months were excluded from the baseline retention average used in the simulator, since the low figures reflect a structural gap in data coverage rather than genuine customer behavior. All other months were retained in the analysis as-is.

### Metric 5: New Customer Acquisition

Calculated by identifying each customer's first-ever purchase month, then counting how many customers were "new" in each month.

**Key finding:** New customer acquisition declined steadily over the two-year period, from roughly 370-440 new customers/month in early 2010 down to approximately 100-220/month by late 2011. Despite this decline, overall monthly revenue (Metric 1) remained relatively stable, suggesting this business has increasingly relied on **repeat purchases from its existing customer base** rather than new customer growth to sustain revenue.

**Data limitation notes:**
- December 2009 (952 new customers) is inflated because it is the first month in the dataset. Every customer active that month is counted as "new" by definition, since there is no prior history to compare against.
- December 2011 (28 new customers) is understated due to the dataset's partial-month cutoff (data ends Dec 9, 2011), consistent with the same limitation noted in the retention metric.

Both months were excluded when calculating the baseline new-customer figure used in the simulator.

### Metric 6: New vs Returning vs Retained Customers

Each month's active customers were split into three groups:
- **New:** buying for the first time ever
- **Retained:** also bought in the previous month
- **Returning:** skipped one or more months, then came back

Using the full months from Jan to Nov 2011, the business gets about **137 new customers** and **526 returning customers** per month. Returning customers are almost 4 times more than new ones. Dec 2009, Jan 2010 and Dec 2011 were left out because the data starts or ends mid-way in those months.

### Summary: Baseline Inputs for the Growth Simulator

| Metric | Baseline Value |
|---|---|
| Average Order Value (AOV) | ~£470 |
| Purchase Frequency | ~1.4 orders/customer/month |
| Monthly Retention Rate | ~38.5% |
| New Customers Acquired | ~137/month (2011 average) |
| Returning Customers | ~526/month (2011 average) |
| Active Customers (avg/month) | ~1,050 |

These real, data-derived baselines are what make the simulator's "what-if" projections credible. Every scenario tested is a percentage adjustment off of these actual historical numbers, not arbitrary assumptions.

## Growth Model

### The idea

Monthly revenue is calculated as:

`Revenue = Customers × Orders per customer × Average order value`

The number of customers changes every month:

`Next month's customers = Customers who stay + New customers + Returning customers`

Think of it as a bucket of customers. Some leak out every month, and new and returning customers pour in. After a few months the two balance out and the number stays steady.

### Baseline inputs (all measured from real data)

| Input | Value |
|---|---|
| Starting active customers | 1,050 |
| Orders per customer per month | 1.4 |
| Average order value | £470 |
| Retention rate (bought again next month) | 38.5% |
| New customers per month | 137 |
| Returning customers per month | 526 |

### How the model was validated

The model gives about £691K to £709K per month. The real average monthly revenue over the 24 full months (Dec 2009 to Nov 2011) is about £703K, so the model is within about 1% of reality.

### First version failed, and how it was fixed

The first version counted only new customers as inflow. It treated a customer who skipped a month as gone forever. Result: customers fell from 1,050 to about 228 and revenue crashed to £150K per month, which never happened in the real data.

Investigation showed that about 526 customers per month were **old customers coming back** after a gap. This is normal for a gift shop, because people do not buy every month. After adding returning customers to the model, customers stayed around 1,050 to 1,078 and revenue settled near £709K per month, matching reality.

### Known limitation

The model has no seasonality. It shows a typical month, not the November peak or the January dip. All scenarios share the same simplification, so the comparison between them is still fair. It also has no costs, so it shows what each lever is worth, not which one gives the best return per £ spent.

## Scenario Results

Each lever was increased by 10% one at a time, with everything else unchanged, and compared with the "do nothing" baseline over 12 months.

| Scenario | 12-Month Revenue | Extra Revenue vs Baseline | Gain |
|---|---|---|---|
| Baseline (no change) | £8,482,264 | - | - |
| Order value (AOV) +10% | £9,330,490 | £848,226 | 10.0% |
| Order frequency +10% | £9,330,490 | £848,226 | 10.0% |
| Returning customers +10% | £9,066,089 | £583,825 | 6.9% |
| Retention +10% | £8,966,560 | £484,296 | 5.7% |
| New customers +10% | £8,634,324 | £152,061 | 1.8% |

### What this means

- **Existing customers matter far more than new ones.** Winning back returning customers is worth about **4 times more** than getting new customers (£584K vs £152K).
- **Why new customers matter least:** they are only about 20% of the customers arriving each month, so a 10% increase in a small group changes little.
- **AOV and frequency give exactly +10%** because revenue is directly multiplied by them. But frequency has stayed between 1.3 and 1.6 in the real data, so raising it is difficult. AOV needs bundling or pricing changes.

## Interactive Simulator

The growth model is available as a Streamlit web app (`src/app.py`).

**Live demo:** _add your Streamlit link here after deployment_

- Five sliders, one per lever: order value (AOV), order frequency, retention, new customers, returning customers
- Each slider changes that lever by a percentage from the real baseline (0% means no change)
- The app runs the model twice, once with the real baseline and once with the slider values, and shows baseline revenue, scenario revenue, extra revenue (£ and %), and a month-by-month chart

A manager can test any combination, for example "AOV +5% and retention +8% together", without writing code.

## Key Findings

1. **This business runs on repeat customers.** About 526 returning and 137 new customers arrive each month, so returning customers are almost 4 times more than new ones.
2. **New customer acquisition declined** from about 370 to 440 per month in early 2010 to about 100 to 220 per month by late 2011, while revenue stayed fairly stable.
3. **Winning back returning customers is worth about 4 times more than acquiring new ones** (+£584K vs +£152K over 12 months for a 10% improvement in each).
4. **Strong seasonality:** revenue peaks every November and dips in January and February. December order value is the highest of the year, with fewer but larger orders.
5. **A naive model fails.** The first version, which counted only new customers, collapsed to £150K per month. Adding returning customers fixed it, because customers in this business skip months and come back.

## Final Recommendations

1. **Run a win-back campaign** for customers who have not ordered in 1 to 3 months.
2. **Raise order value** through bundles or minimum-order offers.
3. **Do not prioritize new customer acquisition first.** It has the lowest payoff in this business.

## Limitations

- **No seasonality:** the model represents a typical month. All scenarios share this simplification, so comparisons between levers remain fair.
- **No costs:** it shows what each lever is worth, not which gives the best return per £ spent.
- **Constant returning customers:** treated as a fixed number per month, though in reality it depends on how many lapsed customers exist.
- **Only identifiable customers:** about 23% of raw rows had no Customer ID and were excluded, so total store revenue is understated.
- **Frequency is hard to raise:** it stayed between 1.3 and 1.6 in the real data, so the +10% frequency scenario is less realistic than it looks.
- **What-if tool, not a forecast:** it shows the effect of changes, not a prediction of the future.

## Tech Stack

- **Python** (pandas) for cleaning and the growth model
- **MySQL** (CTEs, window functions, self-joins) for baseline metrics
- **Streamlit** for the interactive simulator
- **Jupyter Notebook** for the analysis workflow

## Project Structure

```
d2c-revenue-growth-simulator/
├── data/
│   ├── raw/            # original dataset (not tracked)
│   └── processed/      # cleaned dataset
├── notebooks/          # cleaning and growth model notebooks
├── sql/                # baseline_metrics.sql
├── src/
│   └── app.py          # Streamlit simulator
└── README.md
```

## How to Run This Project

1. Clone the repository
2. Install requirements: `pip install streamlit pandas`
3. Start the simulator: `streamlit run src/app.py`

The simulator does not need the dataset, since the baseline numbers from the SQL analysis are stored in `app.py`. To reproduce the analysis, download the [Online Retail II dataset](https://archive.ics.uci.edu/dataset/502/online+retail+ii), run the cleaning notebook, load the cleaned data into MySQL, and run `sql/baseline_metrics.sql`.

## Future Improvements

- Add seasonality so the model reflects the November peak
- Add cost per lever to compare return on spend
- Use RFM segmentation to target the win-back campaign at the right customers

## Data Source

Online Retail II, UCI Machine Learning Repository. Licensed under CC BY 4.0.