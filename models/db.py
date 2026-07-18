from sqlalchemy import Column, String, Float, Integer, Boolean, Text, DateTime
from database import Base
import datetime

class UserDB(Base):
    __tablename__ = "users"

    email = Column(String, primary_key=True, index=True)
    name = Column(String, index=True)
    role = Column(String, default="member")
    is_subscribed = Column(Boolean, default=False)
    balance = Column(Float, default=0.0)
    subscription_plan = Column(String, default="none")

class CommitteeDB(Base):
    __tablename__ = "committees"

    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    description = Column(Text)
    total_amount = Column(Float)
    monthly_contribution = Column(Float)
    members_limit = Column(Integer)
    joined_members = Column(Text)  # Stored as comma-separated string
    installments_paid = Column(Integer, default=0)
    total_installments = Column(Integer)
    draw_winners = Column(Text)    # Stored as comma-separated string
    status = Column(String, default="active")
    frequency = Column(String, default="monthly")

class LoanDB(Base):
    __tablename__ = "loans"

    id = Column(String, primary_key=True, index=True)
    applicant_name = Column(String)
    applicant_email = Column(String)
    amount = Column(Float)
    reason = Column(Text)
    monthly_repayment = Column(Float)
    duration_months = Column(Integer)
    status = Column(String, default="pending")
    date_requested = Column(String)
    installments_paid = Column(Integer, default=0)
    total_repayable = Column(Float)

class ReceiptDB(Base):
    __tablename__ = "receipts"

    id = Column(String, primary_key=True, index=True)
    user_email = Column(String)
    user_name = Column(String)
    type = Column(String)
    amount = Column(Float)
    reference_name = Column(String)
    gateway = Column(String)
    timestamp = Column(String)
