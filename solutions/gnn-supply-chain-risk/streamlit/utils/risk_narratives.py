"""
Risk Narratives - Contextual explanations for regional supply chain risks.

This module provides human-readable risk factor explanations that transform
abstract risk scores into actionable intelligence for the Streamlit UI.

Key regions with critical risk profiles:
- Australia (AUS): Lithium supply concentration + regulatory/climate risks
- DR Congo (COD): Cobalt supply concentration + ESG/conflict risks
"""

# =============================================================================
# Region Risk Narratives
# =============================================================================

REGION_RISK_NARRATIVES = {
    "AUS": {
        "flag": "🇦🇺",
        "name": "Australia",
        "headline": "Critical Risk: Lithium Supply Concentration",
        "summary": (
            "Australia's elevated risk combines regulatory uncertainty, climate exposure, "
            "and infrastructure limitations in a region supplying critical battery-grade lithium."
        ),
        "factors": [
            {
                "icon": "📜",
                "name": "Export Restrictions",
                "risk": "HIGH",
                "desc": "New lithium export restrictions & critical minerals policy (2024)",
            },
            {
                "icon": "🔥",
                "name": "Bushfire Exposure",
                "risk": "HIGH",
                "desc": "Severe bushfire risk in Western Australia mining regions",
            },
            {
                "icon": "💧",
                "name": "Water Scarcity",
                "risk": "HIGH",
                "desc": "Drought conditions affecting mining operations",
            },
            {
                "icon": "🚢",
                "name": "Logistics Challenges",
                "risk": "MEDIUM",
                "desc": "Remote locations, port congestion, long shipping distances",
            },
            {
                "icon": "👷",
                "name": "Labor Disputes",
                "risk": "MEDIUM",
                "desc": "Recent strikes and workforce shortages in mining sector",
            },
        ],
        "bottleneck_connection": "Queensland Minerals",
        "bottleneck_impact": "Supplies 70%+ of battery manufacturers",
        "commodity": "Lithium",
    },
    "COD": {
        "flag": "🇨🇩",
        "name": "DR Congo",
        "headline": "Critical Risk: Cobalt Supply & ESG Exposure",
        "summary": (
            "DR Congo supplies 70% of global cobalt but presents severe geopolitical, "
            "ESG, and infrastructure risks that could disrupt EV battery production."
        ),
        "factors": [
            {
                "icon": "⚔️",
                "name": "Armed Conflict",
                "risk": "CRITICAL",
                "desc": "M23 rebels control mining regions in eastern DRC",
            },
            {
                "icon": "👷",
                "name": "ESG/Child Labor",
                "risk": "CRITICAL",
                "desc": "Artisanal mining practices raise compliance and reputational risk",
            },
            {
                "icon": "🏛️",
                "name": "Political Instability",
                "risk": "HIGH",
                "desc": "Weak governance, corruption, regulatory uncertainty",
            },
            {
                "icon": "🛤️",
                "name": "Infrastructure",
                "risk": "HIGH",
                "desc": "Poor roads, limited power grid, logistics bottlenecks",
            },
            {
                "icon": "📊",
                "name": "Global Dependency",
                "risk": "HIGH",
                "desc": "DRC holds 70% of world's cobalt reserves - no easy alternatives",
            },
        ],
        "bottleneck_connection": "Congo Cobalt Mines",
        "bottleneck_impact": "40% concentration for cobalt supply",
        "commodity": "Cobalt",
    },
}

# Mapping from bottleneck names to their associated regions
BOTTLENECK_TO_REGION = {
    "Queensland Minerals": "AUS",
    "Congo Cobalt Mines": "COD",
}


# =============================================================================
# Risk Level Styling
# =============================================================================

RISK_LEVEL_COLORS = {
    "CRITICAL": {"bg": "rgba(220, 38, 38, 0.2)", "border": "#dc2626", "text": "#fca5a5"},
    "HIGH": {"bg": "rgba(234, 88, 12, 0.2)", "border": "#ea580c", "text": "#fdba74"},
    "MEDIUM": {"bg": "rgba(202, 138, 4, 0.2)", "border": "#ca8a04", "text": "#fde047"},
    "LOW": {"bg": "rgba(22, 163, 74, 0.2)", "border": "#16a34a", "text": "#86efac"},
}


# =============================================================================
# Helper Functions
# =============================================================================

def get_region_narrative(region_code: str) -> dict | None:
    """Get risk narrative for a region code."""
    return REGION_RISK_NARRATIVES.get(region_code)


def get_region_for_bottleneck(bottleneck_name: str) -> str | None:
    """Get region code associated with a bottleneck supplier."""
    return BOTTLENECK_TO_REGION.get(bottleneck_name)


def has_critical_narrative(region_code: str) -> bool:
    """Check if a region has a detailed risk narrative."""
    return region_code in REGION_RISK_NARRATIVES


def render_risk_badge_html(risk_level: str) -> str:
    """Generate HTML for a risk level badge."""
    colors = RISK_LEVEL_COLORS.get(risk_level, RISK_LEVEL_COLORS["MEDIUM"])
    return f'<span style="background: {colors["bg"]}; border: 1px solid {colors["border"]}; color: {colors["text"]}; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: 600;">{risk_level}</span>'


def render_risk_factor_html(factor: dict) -> str:
    """Generate HTML for a single risk factor row."""
    badge = render_risk_badge_html(factor["risk"])
    return (
        f'<div style="display: flex; justify-content: space-between; align-items: flex-start; padding: 0.75rem 0; border-bottom: 1px solid rgba(51, 65, 85, 0.5);">'
        f'<div style="flex: 1;">'
        f'<div style="color: #f8fafc; font-weight: 600; font-size: 0.9rem;">{factor["icon"]} {factor["name"]}</div>'
        f'<div style="color: #94a3b8; font-size: 0.85rem; margin-top: 0.25rem;">{factor["desc"]}</div>'
        f'</div>'
        f'<div style="margin-left: 1rem;">{badge}</div>'
        f'</div>'
    )


def render_risk_intelligence_card(region_code: str, show_bottleneck: bool = True) -> str:
    """
    Generate complete HTML for a Risk Intelligence card.
    
    Args:
        region_code: ISO 3166-1 alpha-3 country code (e.g., 'AUS', 'COD')
        show_bottleneck: Whether to show the connected bottleneck info
        
    Returns:
        HTML string for the risk intelligence card, or empty string if no narrative
    """
    narrative = get_region_narrative(region_code)
    if not narrative:
        return ""
    
    # Build risk factors HTML
    factors_html = "".join(render_risk_factor_html(f) for f in narrative["factors"])
    
    # Build bottleneck connection section
    bottleneck_html = ""
    if show_bottleneck and narrative.get("bottleneck_connection"):
        bottleneck_html = (
            f'<div style="background: rgba(59, 130, 246, 0.1); border: 1px solid #3b82f6; border-radius: 8px; padding: 0.75rem 1rem; margin-top: 1rem;">'
            f'<div style="color: #60a5fa; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em;">📊 Connected Bottleneck</div>'
            f'<div style="color: #f8fafc; font-weight: 600; margin-top: 0.25rem;">{narrative["bottleneck_connection"]}</div>'
            f'<div style="color: #94a3b8; font-size: 0.85rem;">{narrative.get("bottleneck_impact", "")}</div>'
            f'</div>'
        )
    
    # Determine header color based on risk severity
    has_critical = any(f["risk"] == "CRITICAL" for f in narrative["factors"])
    header_color = "#dc2626" if has_critical else "#ea580c"
    
    # Build the card HTML without leading whitespace that could confuse markdown parser
    return (
        f'<div style="background: linear-gradient(135deg, rgba(30, 41, 59, 0.9) 0%, rgba(15, 23, 42, 0.9) 100%); border: 1px solid {header_color}; border-radius: 12px; overflow: hidden; margin: 1rem 0;">'
        f'<div style="background: linear-gradient(135deg, {header_color}22 0%, {header_color}11 100%); border-bottom: 1px solid {header_color}; padding: 1rem 1.25rem;">'
        f'<div style="color: #94a3b8; font-size: 0.85rem; margin-bottom: 0.25rem;">{narrative["flag"]} {narrative["name"].upper()} RISK PROFILE</div>'
        f'<div style="color: {header_color}; font-size: 1.1rem; font-weight: 700;">⚠️ {narrative["headline"]}</div>'
        f'</div>'
        f'<div style="padding: 0.5rem 1.25rem;">'
        f'<div style="color: #cbd5e1; font-size: 0.9rem; line-height: 1.5; padding: 0.75rem 0; border-bottom: 1px solid rgba(51, 65, 85, 0.5);">{narrative["summary"]}</div>'
        f'{factors_html}'
        f'{bottleneck_html}'
        f'</div>'
        f'</div>'
    )


def render_compact_risk_card(region_code: str) -> str:
    """
    Generate a compact version of the risk card for inline display.
    
    Args:
        region_code: ISO 3166-1 alpha-3 country code
        
    Returns:
        HTML string for compact risk card
    """
    narrative = get_region_narrative(region_code)
    if not narrative:
        return ""
    
    # Count risk levels
    critical_count = sum(1 for f in narrative["factors"] if f["risk"] == "CRITICAL")
    high_count = sum(1 for f in narrative["factors"] if f["risk"] == "HIGH")
    
    risk_summary = []
    if critical_count:
        risk_summary.append(f"{critical_count} CRITICAL")
    if high_count:
        risk_summary.append(f"{high_count} HIGH")
    
    risk_text = " · ".join(risk_summary) if risk_summary else "Elevated Risk"
    
    has_critical = critical_count > 0
    border_color = "#dc2626" if has_critical else "#ea580c"
    
    return (
        f'<div style="background: rgba(30, 41, 59, 0.8); border-left: 3px solid {border_color}; border-radius: 0 8px 8px 0; padding: 0.75rem 1rem; margin: 0.5rem 0;">'
        f'<div style="display: flex; justify-content: space-between; align-items: center;">'
        f'<div>'
        f'<span style="color: #f8fafc; font-weight: 600;">{narrative["flag"]} {narrative["name"]}</span>'
        f'<span style="color: #64748b; margin-left: 0.5rem;">— {narrative["commodity"]} Supply Risk</span>'
        f'</div>'
        f'<div style="color: {border_color}; font-size: 0.8rem; font-weight: 600;">{risk_text}</div>'
        f'</div>'
        f'<div style="color: #94a3b8; font-size: 0.85rem; margin-top: 0.25rem;">{narrative["headline"]}</div>'
        f'</div>'
    )

