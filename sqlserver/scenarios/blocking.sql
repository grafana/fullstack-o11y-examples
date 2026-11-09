-- Lock blocking scenario for the bookstore database. No WAITFOR is used: session A
-- holds an open transaction, and session B waits on the same row for as long as
-- A keeps it open (wait type LCK_M_U on the UPDATE).
--
-- Run each session in its own sqlcmd window as bookstore_app, interactively, so
-- session A's connection stays open after its batch finishes. Do NOT use -i for
-- session A: sqlcmd exits at end of file and the transaction rolls back.
--   sqlcmd -S <rds-endpoint>,1433 -U bookstore_app -d bookstore -C
--
-- Nothing here changes data: the UPDATE assigns stock_quantity to itself and
-- session A rolls back at the end.

-- >>> SESSION A: take the row lock and keep the transaction open
BEGIN TRAN;
UPDATE dbo.books_inventory SET stock_quantity = stock_quantity WHERE book_id = 1;
GO
-- <<< SESSION A

-- >>> SESSION B: blocks until session A commits or rolls back
UPDATE dbo.books_inventory SET stock_quantity = stock_quantity WHERE book_id = 1;
GO
-- <<< SESSION B

-- >>> SESSION B (bounded): gives up after 1 second with error 1222 (lock request time out)
SET LOCK_TIMEOUT 1000;
UPDATE dbo.books_inventory SET stock_quantity = stock_quantity WHERE book_id = 1;
GO
-- <<< SESSION B (bounded)

-- >>> SESSION A: release the lock; an unbounded session B now completes
ROLLBACK;
GO
-- <<< SESSION A (release)

-- To watch the block while it is held, connect as the RDS master login (the
-- application and db-o11y logins lack VIEW SERVER STATE) and run:
--   SELECT session_id, blocking_session_id, wait_type, wait_time, status
--   FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
