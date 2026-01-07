# SQL Query Logic Explanation

## Overview
This recursive CTE (Common Table Expression) processes inquiry records for contacts to determine "marketing workable" status based on temporal business rules.

## Business Logic

### Purpose
The query identifies which inquiries are "marketing workable" based on:
1. Whether the inquiry itself is workable (WORKABLE_FLAG = 1)
2. Whether enough time (30 days) has passed since the last marketing workable inquiry

### Step-by-Step Logic with Examples

#### Initial Data Setup
Assume we have the following data in `#all_inquiries`:

| CONTACTID | INQUIRY_DATE | INQUIRY_ORDER_NUM | WORKABLE_FLAG |
|-----------|--------------|-------------------|---------------|
| 1001      | 2024-01-01   | 1                 | 1             |
| 1001      | 2024-01-15   | 2                 | 1             |
| 1001      | 2024-02-10   | 3                 | 1             |
| 1001      | 2024-02-20   | 4                 | 0             |
| 1001      | 2024-03-25   | 5                 | 1             |

#### Recursion Process

**Iteration 1 (Anchor/Base Case):**
Processes only the first inquiry (INQUIRY_ORDER_NUM = 1) for each contact:

| CONTACTID | INQUIRY_DATE | INQUIRY_ORDER_NUM | WORKABLE_FLAG | MKT_WORKABLE_FLAG | LAST_MKT_WORKABLE_DATE |
|-----------|--------------|-------------------|---------------|-------------------|------------------------|
| 1001      | 2024-01-01   | 1                 | 1             | 1                 | 2024-01-01             |

Logic:
- First inquiry simply copies WORKABLE_FLAG to MKT_WORKABLE_FLAG
- If workable (flag = 1), sets LAST_MKT_WORKABLE_DATE to the inquiry date
- If not workable (flag = 0), LAST_MKT_WORKABLE_DATE remains NULL

**Iteration 2 (Recursive Step):**
Processes inquiry #2 by joining with inquiry #1:

| CONTACTID | INQUIRY_DATE | INQUIRY_ORDER_NUM | WORKABLE_FLAG | MKT_WORKABLE_FLAG | LAST_MKT_WORKABLE_DATE |
|-----------|--------------|-------------------|---------------|-------------------|------------------------|
| 1001      | 2024-01-15   | 2                 | 1             | 0                 | 2024-01-01             |

Logic:
- Previous LAST_MKT_WORKABLE_DATE was 2024-01-01
- Current inquiry date is 2024-01-15
- Check: Has 30 days passed? 2024-01-01 + 30 days = 2024-01-31
- Since 2024-01-15 < 2024-01-31, NOT 30 days yet
- Even though WORKABLE_FLAG = 1, MKT_WORKABLE_FLAG = 0 (too soon)
- LAST_MKT_WORKABLE_DATE stays 2024-01-01

**Iteration 3 (Recursive Step):**
Processes inquiry #3 by joining with inquiry #2:

| CONTACTID | INQUIRY_DATE | INQUIRY_ORDER_NUM | WORKABLE_FLAG | MKT_WORKABLE_FLAG | LAST_MKT_WORKABLE_DATE |
|-----------|--------------|-------------------|---------------|-------------------|------------------------|
| 1001      | 2024-02-10   | 3                 | 1             | 1                 | 2024-02-10             |

Logic:
- Previous LAST_MKT_WORKABLE_DATE was 2024-01-01
- Current inquiry date is 2024-02-10
- Check: Has 30 days passed? 2024-01-01 + 30 days = 2024-01-31
- Since 2024-02-10 > 2024-01-31, YES, more than 30 days have passed
- WORKABLE_FLAG = 1 AND 30 days have passed
- MKT_WORKABLE_FLAG = 1 (approved!)
- LAST_MKT_WORKABLE_DATE updates to 2024-02-10

**Iteration 4 (Recursive Step):**
Processes inquiry #4 by joining with inquiry #3:

| CONTACTID | INQUIRY_DATE | INQUIRY_ORDER_NUM | WORKABLE_FLAG | MKT_WORKABLE_FLAG | LAST_MKT_WORKABLE_DATE |
|-----------|--------------|-------------------|---------------|-------------------|------------------------|
| 1001      | 2024-02-20   | 4                 | 0             | 0                 | 2024-02-10             |

Logic:
- Previous LAST_MKT_WORKABLE_DATE was 2024-02-10
- Current inquiry date is 2024-02-20
- WORKABLE_FLAG = 0 (not workable at all)
- MKT_WORKABLE_FLAG = 0 (cannot be marketing workable if not workable)
- LAST_MKT_WORKABLE_DATE stays 2024-02-10 (no change)

**Iteration 5 (Recursive Step):**
Processes inquiry #5 by joining with inquiry #4:

| CONTACTID | INQUIRY_DATE | INQUIRY_ORDER_NUM | WORKABLE_FLAG | MKT_WORKABLE_FLAG | LAST_MKT_WORKABLE_DATE |
|-----------|--------------|-------------------|---------------|-------------------|------------------------|
| 1001      | 2024-03-25   | 5                 | 1             | 1                 | 2024-03-25             |

Logic:
- Previous LAST_MKT_WORKABLE_DATE was 2024-02-10
- Current inquiry date is 2024-03-25
- Check: Has 30 days passed? 2024-02-10 + 30 days = 2024-03-11
- Since 2024-03-25 > 2024-03-11, YES, more than 30 days have passed
- WORKABLE_FLAG = 1 AND 30 days have passed
- MKT_WORKABLE_FLAG = 1 (approved!)
- LAST_MKT_WORKABLE_DATE updates to 2024-03-25

## How Recursion/Looping Works

### Recursive CTE Mechanics

1. **Anchor Member (Base Case):**
   ```sql
   SELECT ... FROM #all_inquiries WHERE INQUIRY_ORDER_NUM = 1
   ```
   - Executes once
   - Selects the first inquiry for each contact
   - Forms the initial result set

2. **Recursive Member:**
   ```sql
   SELECT ... FROM #all_inquiries A JOIN MKT_WORKABLE B
   ON A.CONTACTID = B.CONTACTID AND A.INQUIRY_ORDER_NUM - 1 = B.INQUIRY_ORDER_NUM
   ```
   - Joins current inquiries with previously processed inquiries
   - The join condition `A.INQUIRY_ORDER_NUM - 1 = B.INQUIRY_ORDER_NUM` ensures sequential processing
   - Each iteration processes the next inquiry order number

3. **Looping Process:**
   - **Iteration 1:** Process all records where INQUIRY_ORDER_NUM = 1
   - **Iteration 2:** Join records where INQUIRY_ORDER_NUM = 2 with results from iteration 1
   - **Iteration 3:** Join records where INQUIRY_ORDER_NUM = 3 with results from iteration 2
   - **Iteration N:** Continue until no more records to join (no inquiry_order_num = N exists)

4. **Termination:**
   - Recursion stops when the join produces no new rows
   - `OPTION (MAXRECURSION 0)` removes the default 100-level limit

### Key Decision Points in Each Iteration

For each inquiry after the first:

```
IF previous LAST_MKT_WORKABLE_DATE is NULL
   THEN use current WORKABLE_FLAG as MKT_WORKABLE_FLAG
ELSE
   IF (LAST_MKT_WORKABLE_DATE + 30 days < current INQUIRY_DATE) 
      AND current WORKABLE_FLAG = 1
   THEN MKT_WORKABLE_FLAG = 1 and update LAST_MKT_WORKABLE_DATE
   ELSE MKT_WORKABLE_FLAG = 0 and keep previous LAST_MKT_WORKABLE_DATE
```

### Why This Approach?

The recursive CTE maintains **state** across inquiries:
- Tracks the last date an inquiry was marketing workable
- Ensures the 30-day rule is enforced across the entire inquiry history
- Processes inquiries in chronological order (via INQUIRY_ORDER_NUM)

This pattern is common for:
- Sequential state machines
- Cumulative calculations that depend on previous rows
- Business rules that require "memory" of past events

## Performance Characteristics

### SQL Server Recursive CTE
- **Pros:** 
  - Elegant solution for sequential processing
  - Maintains row-by-row state
  - Clear logic flow

- **Cons:** 
  - Can be slow on large datasets (row-by-row processing)
  - Limited parallelism
  - Memory intensive for deep recursions
  - Not optimized for distributed systems

### Why Convert to Synapse?

Azure Synapse Analytics is a distributed, MPP (Massively Parallel Processing) system that:
- Does not handle recursive CTEs well (poor performance or not supported)
- Excels at set-based operations across distributed nodes
- Requires different optimization strategies

The Synapse conversion will use window functions to achieve the same logic in a set-based manner, allowing for parallel processing and better performance on large datasets.
