#!/usr/bin/env bash
# ==============================================================================
# Complete End-to-End Automated Backend Test Suite
# Enterprise Academic Resource & Circulation Management Platform (Bibliotech)
# ==============================================================================

GATEWAY="http://localhost:8080"
TS=$(date +%s)
STUDENT_USER="student_${TS}"
LIB_USER="librarian_${TS}"
PASS="Test@12345"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

run_test() {
    local test_name="$1"
    local expected_code="$2"
    local actual_code="$3"
    local response="$4"

    if [ "$expected_code" = "$actual_code" ]; then
        echo -e "${GREEN}✓ [PASS]${NC} $test_name (HTTP $actual_code)"
        ((pass_count++))
    else
        echo -e "${RED}✗ [FAIL]${NC} $test_name (Expected HTTP $expected_code, Got $actual_code)"
        echo -e "         Response: $response"
        ((fail_count++))
    fi
}

echo -e "\n${BLUE}======================================================${NC}"
echo -e "${BLUE}  Bibliotech Platform - Automated Backend Test Suite  ${NC}"
echo -e "${BLUE}======================================================${NC}\n"

# ------------------------------------------------------------------------------
# 1. AUTHENTICATION & TOKENS
# ------------------------------------------------------------------------------
echo -e "${YELLOW}>>> [1/7] Authentication & Tokens${NC}"

# 1.1 Register Student
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$STUDENT_USER\",\"password\":\"$PASS\",\"role\":\"STUDENT\"}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Register Student ($STUDENT_USER)" "200" "$CODE" "$BODY"

# 1.2 Login Student
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$STUDENT_USER\",\"password\":\"$PASS\"}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
STUDENT_TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
STUDENT_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('userId', 1))" 2>/dev/null)
run_test "Login Student & Issue JWT" "200" "$CODE" "$BODY"

# 1.3 Register Librarian
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$LIB_USER\",\"password\":\"$PASS\",\"role\":\"LIBRARIAN\"}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Register Librarian ($LIB_USER)" "200" "$CODE" "$BODY"

# 1.4 Login Librarian
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$LIB_USER\",\"password\":\"$PASS\"}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
LIB_TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
run_test "Login Librarian & Issue JWT" "200" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# 2. BOOK MANAGEMENT (INVENTORY)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}>>> [2/7] Book Management & Catalog${NC}"

# 2.1 Add Book (Librarian)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/books" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LIB_TOKEN" \
  -d "{\"title\":\"Enterprise Integration Patterns\",\"author\":\"Gregor Hohpe\",\"availableCopies\":2}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
BOOK_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 1))" 2>/dev/null)
run_test "Add Book as Librarian (Book ID: $BOOK_ID)" "200" "$CODE" "$BODY"

# 2.2 Get All Books (Public)
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/books")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Browse Catalog (Public GET /books)" "200" "$CODE" "$BODY"

# 2.3 Check Availability (Public)
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/books/$BOOK_ID/available")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Check Book Availability (GET /books/$BOOK_ID/available)" "200" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# 3. CIRCULATION & LOAN LIFECYCLE
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}>>> [3/7] Circulation & Loan Lifecycle${NC}"

# 3.1 Borrow Book as Student
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/loans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $STUDENT_TOKEN" \
  -d "{\"userId\":$STUDENT_ID,\"bookId\":$BOOK_ID}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
LOAN_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 1))" 2>/dev/null)
run_test "Borrow Book as Student (Loan ID: $LOAN_ID)" "200" "$CODE" "$BODY"

# 3.2 Duplicate Borrow Check (Should be 409 Conflict)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/loans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $STUDENT_TOKEN" \
  -d "{\"userId\":$STUDENT_ID,\"bookId\":$BOOK_ID}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Prevent Duplicate Borrow (Expect 409)" "409" "$CODE" "$BODY"

# 3.3 Return Book (Triggers Fine Calculation & Increments Copies)
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$GATEWAY/loans/$LOAN_ID/return" \
  -H "Authorization: Bearer $STUDENT_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Return Book (PUT /loans/$LOAN_ID/return)" "200" "$CODE" "$BODY"

# 3.4 Duplicate Return Check (Should be 409 Conflict)
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$GATEWAY/loans/$LOAN_ID/return" \
  -H "Authorization: Bearer $STUDENT_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Prevent Duplicate Return (Expect 409)" "409" "$CODE" "$BODY"

# 3.5 View Loan Details
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/loans/$LOAN_ID" \
  -H "Authorization: Bearer $STUDENT_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "View Loan by ID (GET /loans/$LOAN_ID)" "200" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# 4. OVERDUE TRACKING & NOTIFICATIONS
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}>>> [4/7] Overdue Tracking & Notifications${NC}"

# 4.1 View Overdue Loans (Librarian)
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/loans/overdue" \
  -H "Authorization: Bearer $LIB_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Query Overdue Loans (Librarian Only)" "200" "$CODE" "$BODY"

# 4.2 Trigger Overdue Notification Batch
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/loans/overdue/notify" \
  -H "Authorization: Bearer $LIB_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Trigger Overdue Notifications (POST /loans/overdue/notify)" "200" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# 5. USER PROFILE SERVICE
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}>>> [5/7] User Profile Service${NC}"

# 5.1 Student views own user profile
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/users/$STUDENT_ID" \
  -H "Authorization: Bearer $STUDENT_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Get User Profile (GET /users/$STUDENT_ID)" "200" "$CODE" "$BODY"

# 5.2 Librarian lists all users
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/users" \
  -H "Authorization: Bearer $LIB_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "List All Users (Librarian GET /users)" "200" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# 6. FINE SERVICE
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}>>> [6/7] Fine Management${NC}"

# 6.1 View Fines by Rental
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/fines/rental/$LOAN_ID" \
  -H "Authorization: Bearer $STUDENT_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Query Fines by Loan ID (GET /fines/rental/$LOAN_ID)" "200" "$CODE" "$BODY"

# 6.2 Student tries to settle fine (Should be 403 Forbidden)
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$GATEWAY/fines/1/pay" \
  -H "Authorization: Bearer $STUDENT_TOKEN")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Student Settle Fine Forbidden (Expect 403)" "403" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# 7. SECURITY & ACCESS CONTROL (NEGATIVE TESTS)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}>>> [7/7] Security & RBAC Enforcement${NC}"

# 7.1 Student Attempts Librarian Add Book (Should be 403 Forbidden)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$GATEWAY/books" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $STUDENT_TOKEN" \
  -d "{\"title\":\"Unauthorized\",\"author\":\"Hacker\",\"availableCopies\":1}")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Student Add Book Forbidden (Expect 403)" "403" "$CODE" "$BODY"

# 7.2 Protected Endpoint Without Token (Should be 401 Unauthorized)
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/loans")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Missing JWT Token (Expect 401)" "401" "$CODE" "$BODY"

# 7.3 Protected Endpoint With Invalid Token (Should be 401 Unauthorized)
RESP=$(curl -s -w "\n%{http_code}" -X GET "$GATEWAY/loans" \
  -H "Authorization: Bearer invalidTokenABC123XYZ")
CODE=$(echo "$RESP" | tail -n 1)
BODY=$(echo "$RESP" | sed '$d')
run_test "Malformed/Invalid JWT Token (Expect 401)" "401" "$CODE" "$BODY"

# ------------------------------------------------------------------------------
# SUMMARY REPORT
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}======================================================${NC}"
echo -e "${BLUE}                   TEST SUMMARY                       ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo -e "Total Passed: ${GREEN}$pass_count${NC}"
echo -e "Total Failed: ${RED}$fail_count${NC}"
echo -e "Total Tests:  $((pass_count + fail_count))"
echo -e "${BLUE}======================================================${NC}\n"
