import json
import uuid
from abc import ABC, abstractmethod

import numpy as np
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

CORTEX_SEARCH_SERVICES = "SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.SUPPLY_CHAIN_INFO"
SEMANTIC_MODELS = "@SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.semantic_stage/supply_chain_network.yaml"

# Page settings
st.set_page_config(
    page_title="Supply Chain Assistant",
    page_icon="❄️️",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        "Get Help": None,
        "Report a bug": None,
        "About": (
            "This app contains a chat assistant for a 3-tier supply chain"
            " containing Cortex Search and Cortex Analyst services."
            " It also contains a Supply Chain Optimization Solver."
        ),
    },
)

# Set starting page
if "page" not in st.session_state:
    st.session_state.page = "Welcome"


def set_page(page: str):
    """Set the active page by name."""
    st.session_state.page = page


# Custom CSS styling
st.markdown(
    """
<style>
/* Unified Color Palette */
:root {
    --background-color: #FFFFFF;
    --text-color: #222222;
    --title-color: #1A1A1A;
    --button-color: #1a56db;
    --button-text: #FFFFFF;
    --border-color: #CBD5E0;
    --accent-color: #2C5282;
}

/* General App Styling */
.stApp {
    background-color: var(--background-color);
    color: var(--text-color);
}

/* Title Styling */
h1, .stTitle {
    color: var(--title-color) !important;
    font-size: 36px !important;
    font-weight: 600 !important;
    padding: 1.5rem 0;
}

/* Input Fields */
textarea {
    background-color: white !important;
    border: 1px solid var(--border-color) !important;
    border-radius: 4px !important;
    padding: 16px !important;
    font-size: 16px !important;
    color: var(--text-color) !important;
}

textarea:focus {
    border-color: var(--accent-color) !important;
    box-shadow: 0 0 0 1px var(--accent-color) !important;
}

textarea::placeholder {
    color: #666666 !important;
}

/* Success & Error Messages */
.stException {
    background-color: #FEE2E2 !important;
    border: 1px solid #EF4444 !important;
    padding: 16px !important;
    border-radius: 4px !important;
    margin: 16px 0 !important;
    color: #991B1B !important;
}

div[data-testid="stAlert"], div[data-testid="stException"] {
    background-color: #f8d7da !important;
    color: #721c24 !important;
    border: 1px solid #f5c6cb !important;
    padding: 12px !important;
    border-radius: 6px !important;
    font-weight: bold !important;
}

div[data-testid="stAlertContentError"] {
    color: #721c24 !important;
}

.stFormSubmitButton {
    background-color: white !important;
    padding: 10px;
    border-radius: 8px;
}

button[data-testid="stBaseButton-secondaryFormSubmit"] {
    background-color: #29B5E8 !important;
    color: white !important;
    font-weight: bold !important;
    border-radius: 5px !important;
    padding: 8px 16px !important;
    border: none !important;
}

/* Sidebar Buttons */
.stSidebar button {
    background-color: #29B5E8 !important;
    color: white !important;
    font-weight: 600 !important;
    border: none !important;
}

/* Tooltips */
.tooltip {
    visibility: hidden;
    opacity: 0;
    background-color: white;
    color: var(--text-color);
    padding: 10px;
    border-radius: 10px;
    font-size: 14px;
    line-height: 1.5;
    width: max-content;
    max-width: 300px;
    position: absolute;
    z-index: 1000;
    bottom: calc(100% + 5px);
    left: 50%;
    transform: translateX(-50%);
    transition: opacity 0.3s ease, transform 0.3s ease;
}

.citation:hover + .tooltip {
    visibility: visible;
    opacity: 1;
    transform: translateX(-50%) translateY(0);
}

/* Hide Streamlit Branding */
#MainMenu, footer {
    visibility: hidden;
}

[data-testid="stDownloadButton"] button {
    background-color: #2196F3 !important;
    color: #FFFFFF !important;
    font-weight: 600 !important;
    border: none !important;
    padding: 0.5rem 1rem !important;
    border-radius: 0.375rem !important;
    box-shadow: none !important;
}

.metric-container {
        border: 1px solid #ccc;
        padding: 15px;
        border-radius: 5px;
        text-align: center;
}

.metric-label {
    font-size: 1em;
    color: #555;
}

.metric-value {
    font-size: 1.5em;
    font-weight: bold;
}
</style>
""",
    unsafe_allow_html=True,
)


class Page(ABC):
    """Abstract base class for application pages."""

    @abstractmethod
    def __init__(self):
        pass

    @abstractmethod
    def print_page(self):
        """Render the main page content."""

    @abstractmethod
    def print_sidebar(self):
        """Render the sidebar content."""


def set_default_sidebar():
    """Render the default sidebar with navigation buttons."""
    with st.sidebar:
        st.title("Supply Chain Network Assistant 🚚")
        st.markdown("")
        st.markdown(
            "This application contains a chat assistant for a supply chain"
            " network containing Cortex Search and Cortex Analyst services."
            " It also contains a Supply Chain Optimization Solver."
        )
        st.markdown("")
        if st.button(label="Supply Chain Assistant 💬"):
            set_page("Assistant")
            st.experimental_rerun()
        if st.button(label="Optimization Execution 🚀"):
            set_page("Optimization")
            st.experimental_rerun()
        st.markdown("")
        st.markdown("")
        st.markdown("")
        st.markdown("")
        if st.button(label="Return Home"):
            set_page("Welcome")
            st.experimental_rerun()


def run_snowflake_query(query):
    """Execute a SQL query via Snowpark and return the result DataFrame."""
    try:
        df = session.sql(query.replace(";", ""))

        return df

    except Exception as e:
        st.error(f"Error executing SQL: {str(e)}")
        return None, None


def snowflake_api_call(query: str, limit: int = 10):
    """Query Cortex Search and generate response via Cortex Complete.

    SiS warehouse runtime does not support Cortex Agent API directly.
    Instead we use Cortex Search for retrieval and Cortex Complete for generation.
    """
    from snowflake.core import Root
    from snowflake.cortex import Complete

    try:
        root = Root(session)
        search_service = (
            root.databases["SF_SOLUTIONS"].schemas["SUPPLY_CHAIN_ENTITIES"].cortex_search_services["SUPPLY_CHAIN_INFO"]
        )

        # Search for relevant context
        search_results = search_service.search(
            query,
            columns=["chunk"],
            limit=limit,
        )

        # Build context from search results
        context = ""
        for r in search_results.results:
            context += r.get("chunk", "") + "\n\n"

        # Generate response using Cortex Complete
        prompt = f"""You are a helpful supply chain assistant. Use the context below to answer the user's question.
Be concise and friendly. If the context doesn't contain relevant information, say so.

Context:
{context}

User question: {query}

Answer:"""

        response_text = Complete(model="llama3.1-70b", prompt=prompt)
        return {"content": [{"type": "text", "text": response_text}]}

    except Exception as e:
        return {"_error": f"Exception: {str(e)}"}


def process_sse_response(response):
    """Process agent response - handles both string and structured JSON responses."""
    text = ""
    sql = ""
    interpretation = ""
    citation = ""

    if not response:
        return text, sql, interpretation, citation

    # If response is a plain string (CORTEX.AGENT returns text directly)
    if isinstance(response, str):
        return response, "", "", ""

    # If it has an _error key, it's our error wrapper
    if "_error" in response:
        return "", "", "", ""

    try:
        # Try structured format: {"content": [...]}
        content = response.get("content", [])
        if not content:
            # Try messages format: {"messages": [{"content": ...}]}
            messages = response.get("messages", [])
            if messages:
                last_msg = messages[-1]
                msg_content = last_msg.get("content", "")
                if isinstance(msg_content, str):
                    return msg_content, "", "", ""
                content = msg_content if isinstance(msg_content, list) else []

            # Try choices format: {"choices": [{"message": {"content": ...}}]}
            choices = response.get("choices", [])
            if choices:
                msg = choices[0].get("message", {})
                msg_content = msg.get("content", "")
                if isinstance(msg_content, str):
                    return msg_content, "", "", ""
                content = msg_content if isinstance(msg_content, list) else []

        for content_item in content:
            if not isinstance(content_item, dict):
                text += str(content_item)
                continue
            content_type = content_item.get("type")
            if content_type == "text":
                text += content_item.get("text", "")
                annotations = content_item.get("annotations", [])
                for ann in annotations:
                    if ann.get("type") == "cortex_search_citation":
                        citation += f"\n- {ann.get('text', '')}"
            elif content_type == "tool_result":
                tool_result = content_item.get("tool_result", {})
                for result in tool_result.get("content", []):
                    if result.get("type") == "json":
                        json_data = result.get("json", {})
                        interpretation += json_data.get("text", "")
                        sql = json_data.get("sql", "") or sql

    except Exception:
        # If all parsing fails, dump the response as text
        text = json.dumps(response)[:2000]

    return text, sql, interpretation, citation


low_excess_query = """
    WITH low_inventory AS (
        SELECT
            l.mfg_plant_id AS low_plant_id,
            mp.mfg_plant_name AS low_plant_name,  -- Keep names for reporting
            l.material_id,
            rm.material_name,
            l.quantity_on_hand AS low_qty,
            l.safety_stock_level,
            rm.material_cost,
            l.safety_stock_level * 2 AS low_replenishment_point,
            (low_replenishment_point - l.quantity_on_hand) AS units_needed
        FROM
            SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.mfg_inventory AS l
        JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.mfg_plant AS mp ON l.mfg_plant_id = mp.mfg_plant_id
        JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.raw_material AS rm ON l.material_id = rm.material_id
        WHERE l.quantity_on_hand < l.safety_stock_level
        AND l.days_forward_coverage <= l.material_lead_time + l.lead_time_variability
    ), excess_inventory AS (
        SELECT
            e.mfg_plant_id AS excess_plant_id,
            mp.mfg_plant_name AS excess_plant_name,  -- Keep names for reporting
            e.material_id,
            e.quantity_on_hand AS excess_qty,
            e.safety_stock_level,
            e.safety_stock_level * 2 AS excess_replenishment_point,
            (e.quantity_on_hand - excess_replenishment_point) AS available_to_transfer
        FROM
            SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.mfg_inventory AS e
        JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.mfg_plant AS mp ON e.mfg_plant_id = mp.mfg_plant_id
        WHERE e.quantity_on_hand > 3 * e.safety_stock_level
        AND e.days_forward_coverage > 2 * e.material_lead_time
    )
    SELECT
        l.low_plant_id,
        l.low_plant_name,
        l.material_id,
        l.material_name,
        l.units_needed,
        l.material_cost,
        e.excess_plant_id,
        e.excess_plant_name,
        e.available_to_transfer,
        (l.material_cost * 0.3 * COALESCE(tcs.transport_cost_surcharge, 1.5)) AS transfer_cost_per_unit
    FROM
        low_inventory AS l
    LEFT JOIN excess_inventory AS e ON l.material_id = e.material_id
    LEFT JOIN SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.transport_cost_surcharge AS tcs
        ON e.excess_plant_id = tcs.source_facility_id AND l.low_plant_id = tcs.destination_facility_id
    WHERE e.available_to_transfer > 0  AND l.units_needed > 0 -- Ensure positive transfer amounts
    ORDER BY
        l.low_plant_name,
        l.material_name;
    """

low_excess_df = run_snowflake_query(low_excess_query)


def optimize_transfers():
    """Optimizes material transfers between plants with low and excess inventory.

    This function:
    1. Executes a modified version of the provided SQL query to get
       low/excess inventory data, including transport cost multipliers.
    2. Formulates and solves a linear programming problem to minimize
       total transfer costs.
    3. Inserts the optimal transfer actions into a 'transfer_actions' table.

    Args:
        session: The Snowflake Snowpark session.

    Returns:
        A string indicating success and the number of transfer actions created.
    """
    # --- 1. Get Data from Snowflake (Modified Query) ---

    low_excess_df_pd = low_excess_df.to_pandas()

    # --- 2. Linear Programming Formulation ---

    if low_excess_df_pd.empty:
        return "No transfer opportunities found."

    low_plants = low_excess_df_pd["LOW_PLANT_ID"].unique().tolist()
    excess_plants = low_excess_df_pd["EXCESS_PLANT_ID"].unique().tolist()
    materials = low_excess_df_pd["MATERIAL_ID"].unique().tolist()

    # --- Add Supplier as an "Excess Plant" ---
    supplier_id = "999"  # Use '999' as the supplier ID
    excess_plants.append(supplier_id)

    # --- Linear Programming Formulation ---
    num_low_plants = len(low_plants)
    num_excess_plants = len(excess_plants)
    num_materials = len(materials)
    num_vars = num_low_plants * num_excess_plants * num_materials

    c = np.zeros(num_vars)

    for i, low_plant_id in enumerate(low_plants):
        for j, material_id in enumerate(materials):
            for k, excess_plant_id in enumerate(excess_plants):
                idx = i * num_excess_plants * num_materials + j * num_excess_plants + k

                if excess_plant_id == supplier_id:
                    material_cost = low_excess_df_pd[low_excess_df_pd["MATERIAL_ID"] == material_id][
                        "MATERIAL_COST"
                    ].iloc[0]
                    c[idx] = material_cost
                else:
                    match = low_excess_df_pd[
                        (low_excess_df_pd["LOW_PLANT_ID"] == low_plant_id)
                        & (low_excess_df_pd["EXCESS_PLANT_ID"] == excess_plant_id)
                        & (low_excess_df_pd["MATERIAL_ID"] == material_id)
                    ]
                    if not match.empty:
                        row = match.iloc[0]
                        c[idx] = row["TRANSFER_COST_PER_UNIT"]
                    else:
                        c[idx] = 1e9

    # --- Solve via Greedy Cost Minimization ---
    x = np.zeros(num_vars)

    supply_remaining = {}
    for j, material_id in enumerate(materials):
        for k, excess_plant_id in enumerate(excess_plants):
            if excess_plant_id == supplier_id:
                supply_remaining[(j, k)] = 1e9
            else:
                match = low_excess_df_pd[
                    (low_excess_df_pd["EXCESS_PLANT_ID"] == excess_plant_id)
                    & (low_excess_df_pd["MATERIAL_ID"] == material_id)
                ]
                supply_remaining[(j, k)] = match["AVAILABLE_TO_TRANSFER"].iloc[0] if not match.empty else 0

    demand_remaining = {}
    for i, low_plant_id in enumerate(low_plants):
        for j, material_id in enumerate(materials):
            match = low_excess_df_pd[
                (low_excess_df_pd["LOW_PLANT_ID"] == low_plant_id) & (low_excess_df_pd["MATERIAL_ID"] == material_id)
            ]
            demand_remaining[(i, j)] = match["UNITS_NEEDED"].iloc[0] if not match.empty else 0

    candidates = []
    for i in range(num_low_plants):
        for j in range(num_materials):
            for k in range(num_excess_plants):
                idx = i * num_excess_plants * num_materials + j * num_excess_plants + k
                candidates.append((c[idx], i, j, k, idx))
    candidates.sort(key=lambda t: t[0])

    for cost_val, i, j, k, idx in candidates:
        if cost_val >= 1e9:
            continue
        alloc = min(demand_remaining.get((i, j), 0), supply_remaining.get((j, k), 0))
        if alloc > 0:
            x[idx] = alloc
            demand_remaining[(i, j)] -= alloc
            supply_remaining[(j, k)] -= alloc

    transfer_actions = []
    idx = 0
    for i, low_plant_id in enumerate(low_plants):
        for j, material_id in enumerate(materials):
            for k, excess_plant_id in enumerate(excess_plants):
                transfer_quantity = round(x[idx], 2)
                idx += 1
                if transfer_quantity > 0:
                    if excess_plant_id == supplier_id:
                        material_cost = low_excess_df_pd[low_excess_df_pd["MATERIAL_ID"] == material_id][
                            "MATERIAL_COST"
                        ].iloc[0]
                        transfer_actions.append(
                            {
                                "action_type": "PURCHASE",
                                "source_plant_id": excess_plant_id,
                                "destination_plant_id": low_plant_id,
                                "material_id": material_id,
                                "transfer_quantity": transfer_quantity,
                                "transfer_cost": transfer_quantity * material_cost,
                                "savings": 0.00,
                                "transfer_id": str(uuid.uuid4()),
                                "transfer_date": pd.to_datetime("today").normalize(),
                            }
                        )
                    else:
                        match = low_excess_df_pd[
                            (low_excess_df_pd["LOW_PLANT_ID"] == low_plant_id)
                            & (low_excess_df_pd["EXCESS_PLANT_ID"] == excess_plant_id)
                            & (low_excess_df_pd["MATERIAL_ID"] == material_id)
                        ]
                        if not match.empty:
                            cost_per_unit = match.iloc[0]["TRANSFER_COST_PER_UNIT"]
                            material_cost = low_excess_df_pd[low_excess_df_pd["MATERIAL_ID"] == material_id][
                                "MATERIAL_COST"
                            ].iloc[0]
                            transfer_actions.append(
                                {
                                    "action_type": "TRANSFER",
                                    "source_plant_id": excess_plant_id,
                                    "destination_plant_id": low_plant_id,
                                    "material_id": material_id,
                                    "transfer_quantity": transfer_quantity,
                                    "transfer_cost": transfer_quantity * cost_per_unit,
                                    "savings": transfer_quantity * (material_cost - cost_per_unit),
                                    "transfer_id": str(uuid.uuid4()),
                                    "transfer_date": pd.to_datetime("today").normalize(),
                                }
                            )

    if not transfer_actions:
        return "No optimal transfers found."

    # Create Snowpark DataFrame and write to Snowflake
    pdf = pd.DataFrame(transfer_actions)
    # Ensure ID columns are strings to avoid Arrow int/str mixed-type errors
    for col in ["source_plant_id", "destination_plant_id", "material_id"]:
        if col in pdf.columns:
            pdf[col] = pdf[col].astype(str)
    transfer_actions_df = session.create_dataframe(pdf)
    # Uppercase column rename (not needed currently)
    # transfer_actions_df = transfer_actions_df.rename(
    #     columns={col: col.upper() for col in transfer_actions_df.columns}
    # )
    transfer_actions_df.write.mode("overwrite").save_as_table("SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.transfer_actions")

    return f"Successfully created {len(transfer_actions)} transfer actions."


class WelcomePage(Page):
    """Landing page with overview information."""

    def __init__(self):
        self.name = "Welcome"

    def print_page(self):
        """Render the welcome page content."""
        # Set up main page
        col1, col2 = st.columns((6, 1))
        col1.title("Supply Chain Network Assistant 🚚")

        # Welcome page
        st.subheader("Welcome to your Intelligent Supply Chain Assistant ❄️")

        st.write(
            "This assistant is built in Streamlit, and leverages a Cortex Analyst"
            " Service that knows semantic detail about our supply chain data and can"
            " turn Text-to-SQL, a Cortex Search Service on top of unstructured PDFs"
            " about our Supply Chain, and the Cortex Agents API to correctly route"
            " our questions the correct service and format the answer."
        )

        st.write("")
        st.write("")
        st.write("")

    def print_sidebar(self):
        """Render the welcome page sidebar."""
        set_default_sidebar()


class AssistantPage(Page):
    """Chat interface for the supply chain assistant."""

    def __init__(self):
        self.name = "Assistant"

    def print_page(self):
        """Render the assistant chat page."""
        st.title("Intelligent Supply Chain Network Assistant")

        if "messages" not in st.session_state:
            st.session_state.messages = []

        # Display conversation history
        for message in st.session_state.messages:
            if message["role"] == "user":
                st.markdown(f"**You:** {message['content']}")
            else:
                st.markdown(f"**Assistant:** {message['content'].replace('•', chr(10) + chr(10) + '-')}")
            st.markdown("---")

        # Text input for user query
        query = st.text_input("What would you like to learn?", key="chat_query")
        if st.button("Send") and query:
            st.session_state.messages.append({"role": "user", "content": query})

            # Get response from API
            response = snowflake_api_call(query, 1)

            # Check for API-level errors
            if isinstance(response, dict) and "_error" in response:
                st.session_state.messages.append({"role": "assistant", "content": f"API ERROR: {response['_error']}"})
                st.experimental_rerun()

            text, sql, interpretation, citation = process_sse_response(response)

            if citation:
                st.session_state.messages.append({"role": "assistant", "content": citation})

            if text:
                st.session_state.messages.append({"role": "assistant", "content": text})

            if interpretation:
                st.session_state.messages.append({"role": "assistant", "content": interpretation})

            # If no response content extracted, show debug info
            if not text and not sql and not interpretation and not citation:
                if response:
                    st.session_state.messages.append(
                        {"role": "assistant", "content": f"DEBUG: {json.dumps(response)[:2000]}"}
                    )
                else:
                    st.session_state.messages.append({"role": "assistant", "content": "ERROR: No response from API."})

            # Display SQL if present
            if sql:
                st.session_state.messages.append({"role": "assistant", "content": f"```sql\n{sql}\n```"})
                scn_results = run_snowflake_query(sql)
                if scn_results:
                    st.session_state.messages.append({"role": "assistant", "content": "Query executed successfully."})

            st.experimental_rerun()

    def print_sidebar(self):
        """Render the assistant page sidebar."""
        set_default_sidebar()


class OptimizationPage(Page):
    """Page for supply chain optimization solver."""

    def __init__(self):
        self.name = "Optimization"

    def print_page(self):
        """Render the optimization page with linear programming solver."""
        # Set up main page
        col1, col2 = st.columns((6, 1))
        col1.title("Optimization Execution 🚀")

        # Welcome page
        st.subheader("Our Problem")

        st.write("")
        st.write("""At this point, we've identified manufacturing plants with low inventory of a raw material
        and other plants with excess. An intelligent assistant is great for answering ad-hoc questions like this.""")

        st.write("")
        st.dataframe(low_excess_df)

        st.write(
            "However, this seems to be a regular challenge we want to stay on top of."
            " Let's use [Linear Programming]("
            "https://en.wikipedia.org/wiki/Linear_programming),"
            " also called linear optimization or constraint programming,"
            " to identify the most cost effective way to replenish each plant,"
            " either by transfer or a new purchase from suppliers."
        )

        st.write(
            "Linear programming uses a system of inequalities to define a feasible"
            " regional mathematical space, and a 'solver' that traverses that space"
            " by adjusting a number of decision variables, efficiently finding the"
            " most optimal set of decisions given constraints to meet a stated"
            " objective function."
        )

        st.write(
            "It is possible to also introduce integer-based decision variables,"
            " which transforms the problem from a linear program into a mixed"
            " integer program, but the mechanics are fundamentally the same."
        )

        st.write("The objective function defines the goal - maximizing or minimizing a value, such as profit or costs.")
        st.write(
            "Decision variables are a set of decisions - the values that the solver can change to impact the "
            "objective value."
        )
        st.write(
            "The constraints define the realities of the business - such as only shipping up to a stated capacity."
        )

        st.write(
            "We are utilizing the linprog methods from the [SciPy library](https://scipy.org/), which "
            "is available natively in Snowpark and allows us to define a linear program and use virtually any "
            "solver we want.  In this case, we are using the [HiGHS solver](https://highs.dev/) for our "
            "models."
        )

        submitted = st.button("Optimize for Cost 📊")

        if submitted:
            with st.spinner("Solving Models..."):
                optimize_transfers()
                st.write("")
                transfer_actions = session.table("SF_SOLUTIONS.SUPPLY_CHAIN_ENTITIES.TRANSFER_ACTIONS")
                st.dataframe(transfer_actions)
                st.write("")

                # Calculate the statistics
                df_pandas = transfer_actions.to_pandas()
                transfers_count = len(df_pandas[df_pandas["action_type"] == "TRANSFER"])
                purchases_count = len(df_pandas[df_pandas["action_type"] == "PURCHASE"])
                total_spend = df_pandas["transfer_cost"].sum()
                total_savings = df_pandas["savings"].sum()

                # Use Streamlit columns to display the boxes in a row
                col1, col2, col3, col4 = st.columns(4)

                with col1:
                    st.markdown(
                        f"""
                        <div class="metric-container">
                            <div class="metric-label">Transfers</div>
                            <div class="metric-value">{transfers_count}</div>
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )

                with col2:
                    st.markdown(
                        f"""
                        <div class="metric-container">
                            <div class="metric-label">Purchases</div>
                            <div class="metric-value">{purchases_count}</div>
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )

                with col3:
                    st.markdown(
                        f"""
                        <div class="metric-container">
                            <div class="metric-label">Total Spend</div>
                            <div class="metric-value">${total_spend:,.2f}</div>
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )

                with col4:
                    st.markdown(
                        f"""
                        <div class="metric-container">
                            <div class="metric-label">Savings</div>
                            <div class="metric-value">${total_savings:,.2f}</div>
                        </div>
                        """,
                        unsafe_allow_html=True,
                    )

    def print_sidebar(self):
        """Render the optimization page sidebar."""
        set_default_sidebar()


pages = [WelcomePage(), AssistantPage(), OptimizationPage()]


def main():
    """Route to the active page and render it."""
    for page in pages:
        if page.name == st.session_state.page:
            page.print_page()
            page.print_sidebar()


main()
