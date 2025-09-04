# LLM-Remote-Assistant

An AI-powered mobile assistant designed to remotely control a personal computer using natural language commands. This project leverages a polyglot microservice architecture to achieve a flexible, scalable, and powerful remote assistance tool.

---

## Project Status

**Current Phase: Milestone 3 Complete**

The project has successfully completed its third major milestone: **Checkpoint 3 - Fortifying the Castle (Security & Identity)**.

This crucial phase transformed the project from a functional prototype into a secure, multi-tenant application foundation. The system is no longer an anonymous entity; it now recognizes users, enforces access control, and proactively defends against malicious code execution. We have built the walls and established the gatekeepers.

### Key Achievements in Checkpoint 3:
- **Full Identity Management:** A dedicated microservice, built with **Java and Quarkus**, now manages the entire user lifecycle. It handles user registration, secure password hashing (BCrypt), and login via a persistent **PostgreSQL** database.
- **JWT-Based Authentication:** The system is now secured with **JSON Web Tokens (JWT)**. The Go Gateway acts as a strict gatekeeper, rejecting any WebSocket connection that does not present a valid, signed JWT issued by the identity service.
- **Multi-Layered Security Architecture:**
    - **Gate 1 (LLM Analysis):** A secondary, more powerful LLM now acts as an intelligent pre-filter, analyzing generated code for intent compatibility and general security risks *before* it is ever sent to a client.
    - **Gate 2 (Rust-Powered Static Analysis):** The PC Agent is equipped with a high-performance security engine written in **Rust**. This engine acts as a final line of defense, scanning code for specific malicious patterns and blocking execution locally. The naive `exec()` has been replaced with a security-conscious workflow.
- **Targeted Command Routing:** The communication architecture is now user-aware. Commands sent from a user's mobile client are intelligently routed **only** to that specific user's PC agents, making it architecturally impossible for one user's commands to affect another's.

### Previous Milestones:
- **Checkpoint 2 - First Intelligence:** The core functional loop (`Command -> Generate -> Execute -> Report`) was established, enabling dynamic code generation and remote execution.
- **Checkpoint 1 - The Nervous System:** The foundational infrastructure was laid out with Docker orchestration and a polyglot microservice stack (Go, Python, NGINX).

---

 Stay tuned for updates!