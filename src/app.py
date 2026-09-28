import streamlit as st
import pandas as pd

# ---------- The model (same logic you already built) ----------
def simulate_revenue(starting_customers, frequency, aov, retention_rate,
                     new_customers, returning_customers, months=12):
    results = []
    customers = starting_customers
    for month in range(1, months + 1):
        revenue = customers * frequency * aov
        results.append({"Month": month, "Customers": round(customers), "Revenue": revenue})
        customers = customers * retention_rate + new_customers + returning_customers
    return pd.DataFrame(results)

# ---------- Real baseline numbers from our SQL analysis ----------
BASE = dict(
    starting_customers=1050,
    frequency=1.4,
    aov=470,
    retention_rate=0.385,
    new_customers=137,
    returning_customers=526,
)

# ---------- Page title ----------
st.title("D2C Revenue Growth Simulator")
st.write("Built on 2 years of real transaction data from a UK online gift-ware retailer. "
         "Move the sliders to see what each change is worth over the next 12 months.")

# ---------- Sliders (each one is a % change from the real baseline) ----------
st.sidebar.header("Change a lever")
aov_change = st.sidebar.slider("Order value (AOV) change %", -20, 30, 0)
freq_change = st.sidebar.slider("Order frequency change %", -20, 30, 0)
ret_change = st.sidebar.slider("Retention change %", -20, 30, 0)
new_change = st.sidebar.slider("New customers change %", -20, 30, 0)
back_change = st.sidebar.slider("Returning customers change %", -20, 30, 0)

# ---------- Run baseline and scenario ----------
baseline = simulate_revenue(**BASE)

scenario = simulate_revenue(
    starting_customers=BASE["starting_customers"],
    frequency=BASE["frequency"] * (1 + freq_change / 100),
    aov=BASE["aov"] * (1 + aov_change / 100),
    retention_rate=min(BASE["retention_rate"] * (1 + ret_change / 100), 0.95),
    new_customers=BASE["new_customers"] * (1 + new_change / 100),
    returning_customers=BASE["returning_customers"] * (1 + back_change / 100),
)

base_total = baseline["Revenue"].sum()
scen_total = scenario["Revenue"].sum()
gain = scen_total - base_total

# ---------- Results ----------
col1, col2, col3 = st.columns(3)
col1.metric("Baseline 12-month revenue", f"£{base_total:,.0f}")
col2.metric("Your scenario", f"£{scen_total:,.0f}")
col3.metric("Extra revenue", f"£{gain:,.0f}", f"{gain / base_total * 100:.1f}%")

# ---------- Chart ----------
chart_data = pd.DataFrame({
    "Baseline": baseline["Revenue"],
    "Your scenario": scenario["Revenue"],
}, index=baseline["Month"])
st.subheader("Monthly revenue: baseline vs your scenario")
st.line_chart(chart_data)

st.caption("Note: the model shows a typical month (no seasonality) and has no costs. "
           "It shows what each lever is worth, not what it costs to achieve.")