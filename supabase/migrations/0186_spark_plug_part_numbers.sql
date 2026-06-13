-- 0186_spark_plug_part_numbers.sql
--
-- Put the actual spark plug part number (and acceptable substitutes) on the
-- generator spark-plug maintenance task, so when the task comes due Paul knows
-- exactly what to buy without looking it up. The two Predator 5000 inverter
-- units take an NGK BPR6ES; Harbor Freight has dual-sourced the 5000, so the
-- note says to confirm against the plug actually in the unit. Substitutes are
-- any projected-tip resistor plug of the same heat range. Gap and interval are
-- unchanged from the original task.

update public.maintenance_tasks
   set notes = 'Plug: NGK BPR6ES (gap 0.028-0.031 in, 13/16 in / 21 mm socket). '
            || 'Confirm against the plug in the unit before buying; Harbor Freight dual-sourced the 5000. '
            || 'Acceptable equivalents (projected-tip resistor, same heat range): Champion RN9YC, Denso W20EPR-U, Bosch WR6DC, Autolite 3923. '
            || 'Replace around 300 hours.'
 where task = 'Inspect spark plug';
