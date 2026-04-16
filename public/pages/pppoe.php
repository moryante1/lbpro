<?php
$conns  = Database::fetchAll("SELECT p.*, i.name AS iface FROM pppoe_connections p JOIN interfaces i ON i.id=p.interface_id");
$ifaces = Database::fetchAll("SELECT id,name FROM interfaces ORDER BY name");
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>إدارة PPPoE</h1><p><?= count(array_filter($conns, fn($c)=>$c['status']==='connected')) ?> جلسة نشطة</p></div>
    <button class="btn btn-primary" onclick="openModal('modal-pppoe')">+ اتصال جديد</button>
  </div>
  <div class="grid g2" style="margin-bottom:18px">
    <?php foreach ($conns as $c):
      $up = $c['status']==='connected';
    ?>
    <div class="card">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
        <div>
          <span class="mono" style="font-weight:600;font-size:14px"><?= htmlspecialchars($c['iface']) ?></span>
          <span style="color:var(--text3);font-size:12px;margin-right:8px"><?= htmlspecialchars($c['username']) ?></span>
        </div>
        <span class="badge badge-<?= $up?'green':($c['status']==='connecting'?'amber':'red') ?>">
          <?= ['connected'=>'متصل','disconnected'=>'منقطع','connecting'=>'يتصل...','error'=>'خطأ'][$c['status']] ?? $c['status'] ?>
        </span>
      </div>
      <div class="iface-rows">
        <?php if($c['assigned_ip']): ?><div class="iface-row"><span class="label">IP المُعيَّن</span><span class="val"><?= htmlspecialchars($c['assigned_ip']) ?></span></div><?php endif; ?>
        <div class="iface-row"><span class="label">MTU/MRU</span><span class="val"><?= $c['mtu'] ?>/<?= $c['mru'] ?></span></div>
        <div class="iface-row"><span class="label">LCP Echo</span><span class="val"><?= $c['lcp_echo_interval'] ?>s / <?= $c['lcp_echo_failure'] ?> fails</span></div>
        <div class="iface-row"><span class="label">إعادة اتصال</span><span class="val"><?= $c['persist']?'تلقائي':'يدوي' ?></span></div>
        <?php if($c['connected_at']): ?><div class="iface-row"><span class="label">وقت الاتصال</span><span class="val"><?= $c['connected_at'] ?></span></div><?php endif; ?>
      </div>
      <div style="display:flex;gap:6px;margin-top:12px">
        <?php if(!$up): ?>
        <button class="btn btn-sm btn-success" onclick="pppoeAction(<?= $c['id'] ?>,'connect')">اتصال</button>
        <?php else: ?>
        <button class="btn btn-sm btn-danger" onclick="pppoeAction(<?= $c['id'] ?>,'disconnect')">قطع</button>
        <?php endif; ?>
        <button class="btn btn-sm" onclick="editPppoe(<?= $c['id'] ?>)">تعديل</button>
        <button class="btn btn-sm btn-danger" onclick="deletePppoe(<?= $c['id'] ?>)">حذف</button>
      </div>
    </div>
    <?php endforeach; ?>
    <?php if(!$conns): ?><div class="card"><p style="color:var(--text3);text-align:center">لا توجد اتصالات PPPoE. أضف اتصالاً جديداً.</p></div><?php endif; ?>
  </div>
</div>

<div class="modal-overlay" id="modal-pppoe">
  <div class="modal">
    <div class="modal-header"><div class="modal-title">إضافة اتصال PPPoE</div><div class="modal-close" onclick="closeModal('modal-pppoe')">✕</div></div>
    <form onsubmit="submitPppoe(event)">
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">الواجهة</label>
          <select class="form-select" name="interface_id" required>
            <option value="">اختر...</option>
            <?php foreach($ifaces as $i): ?><option value="<?= $i['id'] ?>"><?= htmlspecialchars($i['name']) ?></option><?php endforeach; ?>
          </select></div>
        <div class="form-group"><label class="form-label">Service Name (اختياري)</label><input class="form-input mono" name="service_name" placeholder="ISP_SERVICE"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">اسم المستخدم</label><input class="form-input mono" name="username" placeholder="user@isp.com" required></div>
        <div class="form-group"><label class="form-label">كلمة المرور</label><input class="form-input" type="password" name="password" required></div>
      </div>
      <div class="form-row fr3">
        <div class="form-group"><label class="form-label">MTU</label><input class="form-input mono" name="mtu" value="1492"></div>
        <div class="form-group"><label class="form-label">MRU</label><input class="form-input mono" name="mru" value="1492"></div>
        <div class="form-group"><label class="form-label">LCP Echo Interval</label><input class="form-input mono" name="lcp_echo_interval" value="30"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">LCP Echo Failures</label><input class="form-input mono" name="lcp_echo_failure" value="4"></div>
        <div class="form-group"><label class="form-label">إعادة اتصال تلقائي</label>
          <select class="form-select" name="persist"><option value="1">نعم</option><option value="0">لا</option></select></div>
      </div>
      <div class="modal-footer"><button type="submit" class="btn btn-primary">إضافة واتصال</button><button type="button" class="btn" onclick="closeModal('modal-pppoe')">إلغاء</button></div>
    </form>
  </div>
</div>
<script>
async function submitPppoe(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = Object.fromEntries(fd);
  body.interface_id = parseInt(body.interface_id);
  body.mtu = parseInt(body.mtu); body.mru = parseInt(body.mru);
  const { data, success, message } = await api.post('/pppoe', body);
  if (success) {
    toast('تمت الإضافة، جاري الاتصال...', 'success');
    await api.post('/pppoe/'+data.id+'/connect');
    closeModal('modal-pppoe');
    setTimeout(()=>location.reload(), 1500);
  } else toast(message||'خطأ', 'error');
}
async function deletePppoe(id) {
  confirmDelete('حذف هذا الاتصال؟', async () => {
    await api.delete('/pppoe/'+id);
    toast('تم الحذف', 'success');
    setTimeout(()=>location.reload(),800);
  });
}
function editPppoe(id) { toast('التعديل قيد التطوير', 'warning'); }
</script>
