import 'package:flutter_test/flutter_test.dart';
import 'package:v3netbill_mobile/features/accounts/models/account.dart';
import 'package:v3netbill_mobile/features/pcs/models/pc.dart';
import 'package:v3netbill_mobile/shared/utils/formatters.dart';

void main() {
  group('PcStatus', () {
    test('memetakan nilai backend ke enum', () {
      expect(PcStatus.fromWire('ACTIVE'), PcStatus.active);
      expect(PcStatus.fromWire('IDLE'), PcStatus.idle);
      expect(PcStatus.fromWire('OFFLINE'), PcStatus.offline);
    });

    test('nilai yang tidak dikenal dianggap idle, tidak membuat crash', () {
      expect(PcStatus.fromWire('APACA'), PcStatus.idle);
      expect(PcStatus.fromWire(null), PcStatus.idle);
    });

    test('PC offline tidak boleh dioperasikan', () {
      expect(PcStatus.offline.canOperate, isFalse);
      expect(PcStatus.active.canOperate, isTrue);
      expect(PcStatus.idle.canOperate, isTrue);
    });
  });

  group('Account', () {
    test('menampilkan kode untuk voucher dan nama untuk member', () {
      const voucher = Account(
        id: '1',
        tipe: AccountType.voucher,
        status: AccountStatus.active,
        kodeUnik: '123456',
      );
      const member = Account(
        id: '2',
        tipe: AccountType.member,
        status: AccountStatus.active,
        nama: 'Budi',
        kodeUnik: '999999',
      );
      expect(voucher.displayName, '123456');
      expect(member.displayName, 'Budi');
    });

    test('sisa nol ditandai habis', () {
      const a = Account(
        id: '1',
        tipe: AccountType.voucher,
        status: AccountStatus.active,
        sisaWaktuDetik: 0,
      );
      expect(a.isHabis, isTrue);
    });
  });

  group('Formatters.duration', () {
    test('di bawah satu jam memakai MM:SS', () {
      expect(Formatters.duration(0), '00:00');
      expect(Formatters.duration(59), '00:59');
      expect(Formatters.duration(1162), '19:22');
    });

    test('satu jam ke atas memakai jam didahulukan', () {
      expect(Formatters.duration(3600), '1j 00:00');
      expect(Formatters.duration(7200), '2j 00:00');
    });

    test('nilai negatif tidak membuat format rusak', () {
      expect(Formatters.duration(-5), '00:00');
    });
  });
}
