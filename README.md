# Bibliotech Platform - Backend Microservices

Cloud-Native Spring Boot Microservices architecture with Netflix Eureka and Spring Cloud Gateway for the Enterprise Academic Resource & Circulation Management Platform.

---

## 🏛️ System Architecture

```
                    +---------------------------+
                    |  API Gateway (Port 8080)  |
                    +-------------+-------------+
                                  | (Routing & Load Balancing)
            +---------------------+---------------------+
            |                     |                     |
  +---------v---------+ +---------v---------+ +---------v---------+
  |    Auth Service   | |    User Service   | |    Book Service   |
  |     Port 8081     | |     Port 8082     | |     Port 8083     |
  +-------------------+ +-------------------+ +---------+---------+
                                                        |
  +-------------------+ +-------------------+           | (Stock Sync)
  |   Eureka Server   | |    Fine Service   |           |
  |     Port 8761     | |     Port 8085     |           |
  +-------------------+ +---------+---------+           |
                                  ^                     |
                                  | (Fee Calculation)   |
                        +---------+---------+           |
                        |    Loan Service   |<----------+
                        |     Port 8084     |
                        +-------------------+
```

---

## 📦 Microservices & Port Mapping

| Service Name | Directory | Registered Eureka ID | Port | Primary Responsibility |
|:---|:---|:---|:---:|:---|
| **Eureka Server** | `eurekaserver/` | `EUREKASERVER` | `8761` | Service registry, heartbeat tracking, and discovery. |
| **API Gateway** | `apigateway/` | `APIGATEWAY` | `8080` | Unified edge router, reverse proxy, and dynamic load balancing. |
| **Auth Service** | `auth-service/` | `AUTH-SERVICE` | `8081` | JWT issuance, password hashing (BCrypt), authentication. |
| **User Service** | `UserService/` | `USERSERVICE` | `8082` | User profiles, role management, user administration. |
| **Book Service** | `bookservice/` | `BOOKSERVICE` | `8083` | Book catalog, stock and copy count management. |
| **Loan Service** | `LoanService/` | `LOANSERVICE` | `8084` | Book borrowing/returns, duplicate checks, overdue tracking. |
| **Fine Service** | `fine-service/` | `FINE-SERVICE` | `8085` | Overdue fee calculations and settlement ledger. |

---

## 🛠️ Build & Run

### Prerequisites
- **JDK 17+**
- **Apache Maven 3.8+**
- **PostgreSQL** running on port `5432` with database `Project` (or configure via `application.properties`)

### 1. Build All Services
From this root directory:
```bash
mvn clean package -DskipTests
```

### 2. Startup Order
Start services in the following order to ensure discovery registry is live:
1. `eurekaserver` (Port 8761)
2. `apigateway` (Port 8080)
3. `auth-service` (Port 8081)
4. `UserService` (Port 8082)
5. `bookservice` (Port 8083)
6. `fine-service` (Port 8085)
7. `LoanService` (Port 8084)

Run each service using:
```bash
cd <service-directory>
mvn spring-boot:run
```
