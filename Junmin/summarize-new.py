#!/usr/bin/env python
import os
import sys
import sqlite3
import numpy as np

conn = None
comm_dict = {}

def spinning_cursor():
    while True:
        for cursor in '|/-\\':
            yield cursor

spinner = spinning_cursor()

def output_spinner():
    global spinner
    sys.stdout.write(spinner.next())  # write the next character
    sys.stdout.flush()                # flush stdout buffer (actual character display)
    sys.stdout.write('\b')            # erase the last written char

# Make a connection to the SQLite3 database
def open_connection(filename):
    global conn
    # check for file to exist
    if not os.path.exists(sqlite_file):
        print "Database file does not exist: ", sqlite_file
        sys.exit(1)

    print "Connecting to:", sqlite_file, "..."
    conn = sqlite3.connect(sqlite_file)
    url = 'file:' + sqlite_file + '?mode=ro'
    conn.isolation_level=None
    conn.text_factory = bytes
    c = conn.cursor()
    return c

# wrapper around queries, for error handling
def try_execute(c, statement, parameters=None):
    success = False
    #print(statement)
    output_spinner()
    while not success:
        try:
            if parameters:
                c.execute(statement,parameters);
            else:
                c.execute(statement);
            success = True
            break
        except sqlite3.Error as e:
            print("database error...", e.args[0])
            success = False
            break

# Create some indices to speed up queries (does it help?)
def make_indices(c):
    #print "Indexing tblpubs...",
    sql_statement = "create index if not exists tblPubs_GUID on tblpubs(prog_name,comm_rank);"
    try_execute(c,sql_statement);
    c.fetchall()
    #print "Indexing tbldata...",
    sql_statement = "create index if not exists tblData_GUID on tbldata(pub_guid,guid,name);"
    try_execute(c,sql_statement);
    c.fetchall()
    #print "Indexing tblvals...",
    sql_statement = "create index if not exists tblVals_GUID on tblvals(guid,frame);"
    try_execute(c,sql_statement);
    c.fetchall()
    #print "done."

# Drop and re-create the view
def make_view(c):
    #print "Recreating view...",
    sql_statement = "DROP VIEW viewCombined;"
    try_execute(c,sql_statement);
    c.fetchall()
    sql_statement = "CREATE VIEW viewCombined AS SELECT tblPubs.process_id AS process_id, tblPubs.node_id AS node_id, tblPubs.title AS pub_title, tblPubs.guid AS pub_guid, tblPubs.comm_rank AS comm_rank, tblPubs.prog_name AS prog_name, tblVals.time_pack AS time_pack, tblVals.time_recv AS time_recv, tblVals.frame AS frame, tblData.name AS value_name, tblData.guid AS value_guid, tblData.val_type AS value_type, tblVals.val AS value FROM tblPubs LEFT OUTER JOIN tblData ON tblPubs.guid = TblData.pub_guid LEFT OUTER JOIN tblVals ON tblData.guid = TblVals.guid;"
    try_execute(c,sql_statement);
    c.fetchall()
    #print "done."

# find all of the ranks participating in the simulation, sending data over SOS
def get_ranks(c):
    sql_statement = "select count(comm_rank) from tblpubs;"
    try_execute(c,sql_statement);
    all_rows = c.fetchall()
    allranks = np.array([x[0] for x in all_rows])
    #sql_statement = "select prog_name, name, count(comm_rank) from tblpubs left outer join tbldata on tblpubs.guid = tbldata.pub_guid where name = 'TAU::MPI::INSTANCE_ID' group by prog_name,name order by prog_name;"
    sql_statement = "select prog_name, value, count(comm_rank) from viewCombined where value_name = 'TAU::MPI::INSTANCE_ID' group by prog_name, value_name order by prog_name;"
    try_execute(c,sql_statement);
    all_rows = c.fetchall()
    prog_names = np.array([x[0] for x in all_rows])
    prog_instances = np.array([x[1] for x in all_rows])
    prog_ranks = np.array([x[2] for x in all_rows])
    sql_statement = "select distinct prog_name, value from viewCombined where value_name = 'TAU::0::Metadata::TAU_SOS_HIGH_RESOLUTION' order by prog_name;"
    try_execute(c,sql_statement);
    all_rows = c.fetchall()
    if len(all_rows) == 0:
        high_res = np.chararray((len(prog_names)))
        high_res[:] = 'off'
    high_res = np.array([x[1] for x in all_rows])
    return allranks[0], prog_names, prog_instances, prog_ranks, high_res

# What was the total time for each application?
# THIS IS BROKEN - apparently SOS gets shut down before the ending timestamp gets written.
# This needs to be fixed in TAU.  In the meantime, use the "get_group_metric" method
# to get the inclusive time spent in ".TAU application"
def get_start_stop(c,prog_name):
    sql_statement = "select value from viewCombined where value_name like '%Metadata::Starting Timestamp' and comm_rank = 0 and prog_name like '" + prog_name + "';"
    try_execute(c,sql_statement);
    all_rows = c.fetchall()
    starttime = np.array([x[0] for x in all_rows]).astype(np.float)
    sql_statement = "select value from viewCombined where value_name like '%Metadata::Ending Timestamp' and comm_rank = 0 and prog_name like '" + prog_name + "';"
    try_execute(c,sql_statement);
    all_rows = c.fetchall()
    endtime = np.array([x[0] for x in all_rows]).astype(np.float)
    return endtime[0] - starttime[0]


# How much <metric> was spent in <group>?
def get_group_metric(c,timer_type,metric,group,prog_name):
    sql_statement = "select cast(COALESCE(NULLIF(value,''), '0') as decimal), value_name, comm_rank, max(frame) from viewCombined where value_name like '%" + timer_type + "_" + metric + "::" + group + "%' and prog_name = '" + prog_name + "' group by value_name, comm_rank;"
    try_execute(c,sql_statement);
    all_rows = c.fetchall()
    alltime = np.array([x[0] for x in all_rows]).astype(np.float)
    return np.sum(alltime)

# How many bytes was sent in <group>?
def get_group_counter(c,group,prog_name,high_res):
    if high_res == 'off':
        sql_statement = "select cast(value as decimal), value_name, comm_rank, max(frame) from viewCombined where value_name like '%Total::" + group + "' and prog_name = '" + prog_name + "' group by value_name, comm_rank;"
        try_execute(c,sql_statement);
        all_rows = c.fetchall()
        bytes = np.array([x[0] for x in all_rows]).astype(np.float)
        sum = np.sum(bytes)
    else:
        sql_statement = "select cast(value as decimal), value_name, comm_rank, max(frame) from viewCombined where value_name like '%Mean::" + group + "' and prog_name = '" + prog_name + "' group by value_name, comm_rank;"
        try_execute(c,sql_statement);
        all_rows = c.fetchall()
        bytes = np.array([x[0] for x in all_rows]).astype(np.float)
        sql_statement = "select cast(value as decimal), value_name, comm_rank, max(frame) from viewCombined where value_name like '%NumEvents::" + group + "' and prog_name = '" + prog_name + "' group by value_name, comm_rank;"
        try_execute(c,sql_statement);
        all_rows = c.fetchall()
        counts = np.array([x[0] for x in all_rows]).astype(np.float)
        sum = 0
        for t,c in zip(bytes,counts):
            sum = sum + (t*c)
    return sum

if len(sys.argv) != 2:
    print("Usage: summarize.py <database>")
    print("Example: ./summarize.py sosd.00000.db")
    sys.exit(0)

# name of the sqlite database file
sqlite_file = sys.argv[1]

# open the connection
c = open_connection(sqlite_file)
#make_indices(c)
#make_view(c)

total_ranks,prog_names,prog_instances,prog_ranks,high_res = get_ranks(c)
print "Total ranks in allocation :", total_ranks, "\n"
for n,i,r,h in zip(prog_names, prog_instances, prog_ranks, high_res):
    print "Ranks in", n, i, ":", r
    if h == "off":
        total_inclusive = get_start_stop(c,n)/1000000
        user_exclusive = (get_group_metric(c,"exclusive","TIME","TAU_USER",n)/1000000)/r
        mpi_exclusive = (get_group_metric(c,"exclusive","TIME","MPI",n)/1000000)/r
        adios_exclusive = (get_group_metric(c,"exclusive","TIME","TAU_IO",n)/1000000)/r
        mpi_collective_bytes = get_group_counter(c,"Collective Bytes Sent",n,h)
        mpi_recv_bytes = get_group_counter(c,"MPI Receive Bytes",n,h)
        mpi_send_bytes = get_group_counter(c,"MPI Send Bytes",n,h)
        io_read_bytes = get_group_counter(c,"IO Bytes Read",n,h)
        io_write_bytes = get_group_counter(c,"IO Bytes Written",n,h)
        adios_write_bytes = get_group_counter(c,"ADIOS data size",n,h)
    else:
        total_inclusive = (get_group_metric(c,"inclusive","TIME",".TAU application",n)/1000000)/r
        mpi_exclusive = (get_group_metric(c,"exclusive","TIME","MPI_",n)/1000000)/r
        adios_exclusive = (get_group_metric(c,"exclusive","TIME","adios_",n)/1000000)/r
        user_exclusive = total_inclusive - (mpi_exclusive + adios_exclusive)
        mpi_collective_bytes = get_group_counter(c,"Message size for %",n,h)
        mpi_recv_bytes = get_group_counter(c,"Message size received from all nodes",n,h)
        mpi_send_bytes = get_group_counter(c,"Message size sent to all nodes",n,h)
        io_read_bytes = get_group_counter(c,"Bytes Read",n,h)
        io_write_bytes = get_group_counter(c,"Bytes Written",n,h)
        adios_write_bytes = get_group_counter(c,"ADIOS data size",n,h)
    print "\t","Total time :",total_inclusive,"seconds"
    print "\t","User  time :",user_exclusive,"seconds"
    print "\t","MPI   time :",mpi_exclusive,"seconds (",(mpi_exclusive/total_inclusive)*100,"% )"
    print "\t","ADIOS time :",adios_exclusive,"seconds (",(adios_exclusive/total_inclusive)*100,"% )"
    print "\t","MPI collective bytes   :",mpi_collective_bytes
    print "\t","MPI P2P bytes sent     :",mpi_send_bytes
    print "\t","MPI P2P bytes received :",mpi_recv_bytes
    #print "\t","Posix IO bytes read    :",io_read_bytes
    #print "\t","Posix IO bytes written :",io_write_bytes
    print "\t","ADIOS bytes written    :",adios_write_bytes
    print ""
