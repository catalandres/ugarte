trigger Product2Trigger on Product2 (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    Ugarte.handle(Trigger.operationType, Trigger.new);
}